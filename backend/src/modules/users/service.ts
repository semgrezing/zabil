import { FastifyInstance } from 'fastify'
import sharp from 'sharp'
import { v4 as uuidv4 } from 'uuid'
import path from 'path'
import fs from 'fs'
import { errors } from '../../utils/errors.js'
import { env } from '../../config/env.js'
import {
  ALLOWED_MIME_TYPES,
  ALLOWED_EXTENSIONS,
  checkMagicBytes,
  ensureUploadDir as ensureDir,
} from '../../utils/upload-helpers.js'

function resolveAvatarPath(avatarUrl: string) {
  const filename = avatarUrl.split('/').pop() ?? ''
  return path.join(env.UPLOADS_PATH, 'avatars', filename)
}

export async function getMe(app: FastifyInstance, userId: string) {
  const user = await app.prisma.user.findUnique({
    where: { id: userId },
    select: userProfileSelect,
  })
  if (!user) throw errors.notFound('Пользователь')
  return user
}

export async function updateProfile(
  app: FastifyInstance,
  userId: string,
  dto: {
    username?: string
    displayName?: string | null
    notePushEnabled?: boolean
    checklistPushEnabled?: boolean
    releasePushEnabled?: boolean
  },
) {
  const username = dto.username?.trim()
  if (username && username.length > 0) {
    const existing = await app.prisma.user.findUnique({
      where: { username },
      select: { id: true },
    })
    if (existing && existing.id !== userId) {
      throw errors.conflict('Пользователь с таким именем уже существует')
    }
  }

  const hasDisplayName = Object.prototype.hasOwnProperty.call(dto, 'displayName')
  const rawDisplayName = hasDisplayName ? dto.displayName?.trim() : undefined
  const displayName = rawDisplayName && rawDisplayName.length > 0 ? rawDisplayName : null

  const user = await app.prisma.user.update({
    where: { id: userId },
    data: {
      ...(username ? { username } : {}),
      ...(hasDisplayName ? { displayName } : {}),
      ...(dto.notePushEnabled != null
          ? { notePushEnabled: dto.notePushEnabled }
          : {}),
      ...(dto.checklistPushEnabled != null
          ? { checklistPushEnabled: dto.checklistPushEnabled }
          : {}),
      ...(dto.releasePushEnabled != null
          ? { releasePushEnabled: dto.releasePushEnabled }
          : {}),
    },
    select: userProfileSelect,
  })
  return user
}

export async function uploadAvatar(
  app: FastifyInstance,
  userId: string,
  file: {
    filename: string
    mimetype: string
    file: NodeJS.ReadableStream
  },
) {
  if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
    throw errors.badRequest('Допустимы только изображения: jpg, png, webp')
  }

  const ext = path.extname(file.filename).toLowerCase()
  if (!ALLOWED_EXTENSIONS.has(ext)) {
    throw errors.badRequest('Недопустимое расширение файла')
  }

  const chunks: Buffer[] = []
  let totalSize = 0

  for await (const chunk of file.file) {
    totalSize += chunk.length
    if (totalSize > env.MAX_UPLOAD_SIZE) {
      throw errors.badRequest(`Файл превышает максимальный размер ${env.MAX_UPLOAD_SIZE / 1024 / 1024}MB`)
    }
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk))
  }

  const buffer = Buffer.concat(chunks)

  if (!checkMagicBytes(buffer, file.mimetype)) {
    throw errors.badRequest('Файл не является изображением')
  }

  const outputFilename = `${uuidv4()}.webp`
  const uploadDir = path.join(env.UPLOADS_PATH, 'avatars')
  ensureDir(uploadDir)
  const outputPath = path.join(uploadDir, outputFilename)

  await sharp(buffer)
    .resize({ width: 512, height: 512, fit: 'cover' })
    .webp({ quality: 85 })
    .toFile(outputPath)

  const avatarUrl = `/uploads/avatars/${outputFilename}`

  const current = await app.prisma.user.findUnique({
    where: { id: userId },
    select: { avatarUrl: true },
  })
  if (!current) throw errors.notFound('Пользователь')

  await app.prisma.$transaction(async (tx) => {
    await tx.avatarHistory.create({
      data: {
        entityType: 'user',
        entityId: userId,
        avatarUrl,
      },
    })

    await tx.user.update({
      where: { id: userId },
      data: { avatarUrl },
    })
  })

  return app.prisma.user.findUnique({
    where: { id: userId },
    select: userProfileSelect,
  })
}

export async function getAvatarHistory(app: FastifyInstance, userId: string) {
  return app.prisma.avatarHistory.findMany({
    where: { entityType: 'user', entityId: userId },
    orderBy: { createdAt: 'desc' },
  })
}

export async function deleteAvatar(app: FastifyInstance, userId: string) {
  const current = await app.prisma.user.findUnique({
    where: { id: userId },
    select: { avatarUrl: true },
  })
  if (!current) throw errors.notFound('Пользователь')
  if (!current.avatarUrl) return { deleted: false }

  await app.prisma.user.update({
    where: { id: userId },
    data: { avatarUrl: null },
  })

  return { deleted: true }
}

export async function deleteAvatarHistoryItem(
  app: FastifyInstance,
  userId: string,
  historyId: string,
) {
  const item = await app.prisma.avatarHistory.findUnique({ where: { id: historyId } })
  if (!item || item.entityType !== 'user' || item.entityId !== userId) {
    throw errors.notFound('Аватар')
  }

  const current = await app.prisma.user.findUnique({
    where: { id: userId },
    select: { avatarUrl: true },
  })

  await app.prisma.$transaction(async (tx) => {
    if (current?.avatarUrl === item.avatarUrl) {
      await tx.user.update({ where: { id: userId }, data: { avatarUrl: null } })
    }
    await tx.avatarHistory.delete({ where: { id: historyId } })
  })

  try {
    const p = resolveAvatarPath(item.avatarUrl)
    if (fs.existsSync(p)) fs.unlinkSync(p)
  } catch (_) {
    // best-effort cleanup
  }

  return { deleted: true }
}

const ONLINE_THRESHOLD_MS = 3 * 60 * 1000 // 3 minutes

export function computeIsOnline(lastSeenAt: Date | null): boolean {
  if (!lastSeenAt) return false
  return Date.now() - lastSeenAt.getTime() < ONLINE_THRESHOLD_MS
}

export async function getUserPublicProfile(
  app: FastifyInstance,
  requesterId: string,
  targetUserId: string,
) {
  const user = await app.prisma.user.findUnique({
    where: { id: targetUserId },
    select: { id: true, username: true, displayName: true, avatarUrl: true, lastSeenAt: true },
  })
  if (!user) throw errors.notFound('Пользователь')

  const commonMemberships = await app.prisma.groupMember.findMany({
    where: {
      userId: requesterId,
      group: {
        isPersonal: false,
        members: {
          some: { userId: targetUserId },
        },
      },
    },
    select: {
      groupId: true,
      group: {
        select: {
          id: true,
          title: true,
          avatarUrl: true,
          members: { select: { userId: true } },
        },
      },
    },
    orderBy: { group: { title: 'asc' } },
  })

  const avatarHistory = await app.prisma.avatarHistory.findMany({
    where: { entityType: 'user', entityId: targetUserId },
    orderBy: { createdAt: 'desc' },
    select: { id: true, avatarUrl: true, createdAt: true },
    take: 30,
  })

  const isOnline = computeIsOnline(user.lastSeenAt)
  return {
    user: {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      lastSeenAt: user.lastSeenAt?.toISOString() ?? null,
      isOnline,
    },
    avatarHistory,
    commonGroups: commonMemberships.map((m) => ({
      id: m.group.id,
      title: m.group.title,
      avatarUrl: m.group.avatarUrl,
      membersCount: m.group.members.length,
    })),
  }
}
