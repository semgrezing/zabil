import { FastifyInstance } from 'fastify'
import sharp from 'sharp'
import { v4 as uuidv4 } from 'uuid'
import fs from 'fs'
import path from 'path'
import { CreateGroupDto, UpdateGroupDto } from './schema.js'
import { errors } from '../../utils/errors.js'
import { env } from '../../config/env.js'
import { notifyGroupDeleted, notifyGroupMemberRemoved } from '../notifications/service.js'

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp'])
const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp'])
const MAGIC_BYTES: Record<string, number[]> = {
  'image/jpeg': [0xff, 0xd8, 0xff],
  'image/png': [0x89, 0x50, 0x4e, 0x47],
  'image/webp': [0x52, 0x49, 0x46, 0x46],
}

function ensureDir(dir: string) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true })
  }
}

function checkMagicBytes(buffer: Buffer, mimeType: string): boolean {
  const magic = MAGIC_BYTES[mimeType]
  if (!magic) return false
  return magic.every((byte, i) => buffer[i] === byte)
}

function resolveGroupAvatarPath(avatarUrl: string) {
  const filename = avatarUrl.split('/').pop() ?? ''
  return path.join(env.UPLOADS_PATH, 'group-avatars', filename)
}

async function requireManageRole(app: FastifyInstance, groupId: string, userId: string) {
  const member = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
    select: { role: true },
  })
  if (!member) throw errors.forbidden()
  if (!['owner', 'admin'].includes(member.role)) throw errors.forbidden()
  return member.role
}

export async function ensurePersonalGroup(app: FastifyInstance, userId: string) {
  const existing = await app.prisma.group.findFirst({
    where: { createdBy: userId, isPersonal: true },
    select: { id: true },
  })
  if (existing) return existing

  return app.prisma.group.create({
    data: {
      title: 'Личное',
      createdBy: userId,
      isPersonal: true,
      members: {
        create: {
          userId,
          role: 'owner',
        },
      },
    },
    select: { id: true },
  })
}

export async function createGroup(app: FastifyInstance, userId: string, dto: CreateGroupDto) {
  const group = await app.prisma.group.create({
    data: {
      title: dto.title,
      createdBy: userId,
      isPersonal: false,
      members: {
        create: {
          userId,
          role: 'owner',
        },
      },
    },
    include: {
      members: {
        include: {
          user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        },
      },
    },
  })

  return group
}

export async function getUserGroups(app: FastifyInstance, userId: string) {
  const members = await app.prisma.groupMember.findMany({
    where: {
      userId,
      group: {
        isPersonal: false,
      },
    },
    include: {
      group: {
        include: {
          members: {
            include: {
              user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
            },
          },
        },
      },
    },
    orderBy: { joinedAt: 'desc' },
  })

  return members.map((m) => m.group)
}

export async function getPersonalContext(app: FastifyInstance, userId: string) {
  const personal = await ensurePersonalGroup(app, userId)
  return {
    id: personal.id,
    title: 'Личное',
    isPersonal: true,
  }
}

export async function getUserGroupsWithPersonal(app: FastifyInstance, userId: string) {
  const members = await app.prisma.groupMember.findMany({
    where: { userId },
    include: {
      group: {
        include: {
          members: {
            include: {
              user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
            },
          },
        },
      },
    },
    orderBy: { joinedAt: 'desc' },
  })

  return members.map((m) => m.group)
}

export async function getGroupById(app: FastifyInstance, groupId: string, userId: string) {
  const member = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  })
  if (!member) throw errors.forbidden()

  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    include: {
      members: {
        include: {
          user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        },
      },
    },
  })
  if (!group) throw errors.notFound('Группа')

  return group
}

export async function updateGroup(
  app: FastifyInstance,
  groupId: string,
  userId: string,
  dto: UpdateGroupDto,
) {
  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    select: { id: true, isPersonal: true },
  })
  if (!group) throw errors.notFound('Группа')
  if (group.isPersonal) throw errors.badRequest('Личную группу нельзя переименовать')

  await requireManageRole(app, groupId, userId)

  return app.prisma.group.update({
    where: { id: groupId },
    data: { title: dto.title.trim() },
    include: {
      members: {
        include: {
          user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        },
      },
    },
  })
}

export async function removeGroupMember(
  app: FastifyInstance,
  groupId: string,
  actorUserId: string,
  targetUserId: string,
) {
  await requireManageRole(app, groupId, actorUserId)

  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    select: { title: true },
  })
  if (!group) throw errors.notFound('Группа')

  const actor = await app.prisma.user.findUnique({
    where: { id: actorUserId },
    select: { username: true, displayName: true },
  })

  const target = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId: targetUserId } },
    select: { role: true },
  })
  if (!target) throw errors.notFound('Участник')

  if (target.role === 'owner' || target.role === 'admin') {
    throw errors.badRequest('Нельзя исключить владельца или администратора')
  }

  await app.prisma.groupMember.delete({
    where: { groupId_userId: { groupId, userId: targetUserId } },
  })

  notifyGroupMemberRemoved(app, {
    userId: targetUserId,
    groupId,
    groupTitle: group.title,
    actorName: actor?.displayName?.trim() || actor?.username || 'Участник',
  }).catch((e: unknown) =>
    console.error('[notify] notifyGroupMemberRemoved:', e),
  )

  return { removed: true }
}

export async function uploadGroupAvatar(
  app: FastifyInstance,
  groupId: string,
  userId: string,
  file: {
    filename: string
    mimetype: string
    file: NodeJS.ReadableStream
  },
) {
  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    select: { id: true, isPersonal: true, avatarUrl: true },
  })
  if (!group) throw errors.notFound('Группа')
  if (group.isPersonal) throw errors.badRequest('Для личного контекста аватарка недоступна')

  await requireManageRole(app, groupId, userId)

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
  const uploadDir = path.join(env.UPLOADS_PATH, 'group-avatars')
  ensureDir(uploadDir)
  const outputPath = path.join(uploadDir, outputFilename)

  await sharp(buffer)
    .resize({ width: 512, height: 512, fit: 'cover' })
    .webp({ quality: 85 })
    .toFile(outputPath)

  const avatarUrl = `/uploads/group-avatars/${outputFilename}`

  await app.prisma.$transaction(async (tx) => {
    await tx.avatarHistory.create({
      data: {
        entityType: 'group',
        entityId: groupId,
        avatarUrl,
      },
    })

    await tx.group.update({
      where: { id: groupId },
      data: { avatarUrl },
    })
  })

  return app.prisma.group.findUnique({
    where: { id: groupId },
    include: {
      members: {
        include: {
          user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        },
      },
    },
  })
}

export async function getGroupAvatarHistory(app: FastifyInstance, groupId: string, userId: string) {
  const member = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  })
  if (!member) throw errors.forbidden()

  return app.prisma.avatarHistory.findMany({
    where: { entityType: 'group', entityId: groupId },
    orderBy: { createdAt: 'desc' },
  })
}

export async function deleteGroupAvatar(app: FastifyInstance, groupId: string, userId: string) {
  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    select: { avatarUrl: true, isPersonal: true },
  })
  if (!group) throw errors.notFound('Группа')
  if (group.isPersonal) throw errors.badRequest('Для личного контекста аватарка недоступна')

  await requireManageRole(app, groupId, userId)

  if (!group.avatarUrl) return { deleted: false }

  try {
    const p = resolveGroupAvatarPath(group.avatarUrl)
    if (fs.existsSync(p)) fs.unlinkSync(p)
  } catch (_) {
    // best-effort cleanup
  }

  await app.prisma.group.update({
    where: { id: groupId },
    data: { avatarUrl: null },
  })

  return { deleted: true }
}

export async function deleteGroupAvatarHistoryItem(
  app: FastifyInstance,
  groupId: string,
  userId: string,
  historyId: string,
) {
  await requireManageRole(app, groupId, userId)

  const item = await app.prisma.avatarHistory.findUnique({
    where: { id: historyId },
  })
  if (!item || item.entityType !== 'group' || item.entityId !== groupId) {
    throw errors.notFound('Аватар')
  }

  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    select: { avatarUrl: true },
  })

  await app.prisma.$transaction(async (tx) => {
    if (group?.avatarUrl === item.avatarUrl) {
      await tx.group.update({ where: { id: groupId }, data: { avatarUrl: null } })
    }
    await tx.avatarHistory.delete({ where: { id: historyId } })
  })

  try {
    const p = resolveGroupAvatarPath(item.avatarUrl)
    if (fs.existsSync(p)) fs.unlinkSync(p)
  } catch (_) {
    // best-effort cleanup
  }

  return { deleted: true }
}

/**
 * Удаление группы. Только creator (role=owner). Каскадно (через схему)
 * удалит members / invitations / notes / chat messages.
 */
export async function deleteGroup(app: FastifyInstance, groupId: string, userId: string) {
  const group = await app.prisma.group.findUnique({
    where: { id: groupId },
    include: {
      members: true,
    },
  })
  if (!group) throw errors.notFound('Группа')
  if (group.createdBy !== userId) {
    throw errors.forbidden()
  }

  const actor = await app.prisma.user.findUnique({
    where: { id: userId },
    select: { username: true, displayName: true },
  })

  const recipients = group.members
    .map((m) => m.userId)
    .filter((id) => id !== userId)

  const avatars = await app.prisma.avatarHistory.findMany({
    where: { entityType: 'group', entityId: groupId },
    select: { avatarUrl: true },
  })

  await app.prisma.$transaction(async (tx) => {
    const noteIds = await tx.note.findMany({
      where: { groupId },
      select: { id: true },
    })
    const ids = noteIds.map((n) => n.id)

    if (ids.length > 0) {
      await tx.noteChecklistItem.deleteMany({
        where: { noteId: { in: ids } },
      })
      await tx.noteImage.deleteMany({
        where: { noteId: { in: ids } },
      })
    }

    await tx.groupChatMessage.deleteMany({ where: { groupId } })
    await tx.invitation.deleteMany({ where: { groupId } })
    await tx.groupMember.deleteMany({ where: { groupId } })
    await tx.avatarHistory.deleteMany({ where: { entityType: 'group', entityId: groupId } })
    await tx.note.deleteMany({ where: { groupId } })
    await tx.group.delete({ where: { id: groupId } })
  })

  try {
    if (group.avatarUrl) {
      const p = resolveGroupAvatarPath(group.avatarUrl)
      if (fs.existsSync(p)) fs.unlinkSync(p)
    }
    for (const a of avatars) {
      const p = resolveGroupAvatarPath(a.avatarUrl)
      if (fs.existsSync(p)) fs.unlinkSync(p)
    }
  } catch (_) {
    // best-effort cleanup
  }

  await Promise.all(
    recipients.map((targetUserId) =>
      notifyGroupDeleted(app, {
        userId: targetUserId,
        groupId,
        groupTitle: group.title,
        actorName: actor?.displayName?.trim() || actor?.username || 'Владелец',
      }).catch((e: unknown) =>
        console.error('[notify] notifyGroupDeleted:', e),
      ),
    ),
  )

  return { deleted: true }
}

export async function leaveGroup(app: FastifyInstance, groupId: string, userId: string) {
  const member = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  })
  if (!member) throw errors.notFound('Участник')

  if (member.role === 'owner') {
    const otherMembers = await app.prisma.groupMember.count({
      where: { groupId, userId: { not: userId } },
    })
    if (otherMembers > 0) {
      throw errors.badRequest('Передайте роль владельца другому участнику перед выходом')
    }
    await deleteGroup(app, groupId, userId)
    return { deleted: true }
  }

  await app.prisma.groupMember.delete({
    where: { groupId_userId: { groupId, userId } },
  })
  return { deleted: false }
}
