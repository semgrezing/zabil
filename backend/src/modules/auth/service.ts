import bcrypt from 'bcrypt'
import { v4 as uuidv4 } from 'uuid'
import { FastifyInstance } from 'fastify'
import { RegisterDto, LoginDto } from './schema.js'
import { errors } from '../../utils/errors.js'
import { env } from '../../config/env.js'

const BCRYPT_ROUNDS = 12

function addDays(date: Date, days: number): Date {
  const result = new Date(date)
  result.setDate(result.getDate() + days)
  return result
}

export async function registerUser(app: FastifyInstance, dto: RegisterDto) {
  const existing = await app.prisma.user.findUnique({
    where: { username: dto.username },
  })
  if (existing) {
    throw errors.conflict('Пользователь с таким именем уже существует')
  }

  const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS)

  const user = await app.prisma.user.create({
    data: {
      username: dto.username,
      passwordHash,
    },
  })

  const tokens = await issueTokens(app, user.id, user.username)

  return {
    user: {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      notePushEnabled: user.notePushEnabled,
      checklistPushEnabled: user.checklistPushEnabled,
      releasePushEnabled: user.releasePushEnabled,
    },
    ...tokens,
  }
}

export async function loginUser(app: FastifyInstance, dto: LoginDto) {
  const user = await app.prisma.user.findUnique({
    where: { username: dto.username },
  })
  if (!user) {
    throw errors.badRequest('Неверное имя пользователя или пароль')
  }

  const valid = await bcrypt.compare(dto.password, user.passwordHash)
  if (!valid) {
    throw errors.badRequest('Неверное имя пользователя или пароль')
  }

  const tokens = await issueTokens(app, user.id, user.username)
  return {
    user: {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      notePushEnabled: user.notePushEnabled,
      checklistPushEnabled: user.checklistPushEnabled,
      releasePushEnabled: user.releasePushEnabled,
    },
    ...tokens,
  }
}

export async function refreshTokens(app: FastifyInstance, refreshToken: string) {
  const stored = await app.prisma.refreshToken.findUnique({
    where: { token: refreshToken },
    include: { user: true },
  })

  if (!stored || stored.expiresAt < new Date()) {
    // Clean up expired token if it exists
    if (stored) {
      await app.prisma.refreshToken.delete({ where: { id: stored.id } })
    }
    throw errors.unauthorized()
  }

  // Rotate: delete old, issue new
  await app.prisma.refreshToken.delete({ where: { id: stored.id } })
  const tokens = await issueTokens(app, stored.user.id, stored.user.username)

  return tokens
}

export async function logoutUser(app: FastifyInstance, refreshToken: string) {
  await app.prisma.refreshToken.deleteMany({
    where: { token: refreshToken },
  })
}

export async function issueTokens(app: FastifyInstance, userId: string, username: string) {
  const accessToken = app.jwt.sign(
    { userId, username },
    { expiresIn: env.JWT_ACCESS_EXPIRES }
  )

  // Clean up expired tokens for this user
  await app.prisma.refreshToken.deleteMany({
    where: { userId, expiresAt: { lt: new Date() } },
  })

  // Enforce max 10 active tokens per user (delete oldest)
  const activeTokens = await app.prisma.refreshToken.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true },
  })
  if (activeTokens.length >= 10) {
    const toDelete = activeTokens.slice(0, activeTokens.length - 9).map((t) => t.id)
    await app.prisma.refreshToken.deleteMany({ where: { id: { in: toDelete } } })
  }

  const rawRefreshToken = uuidv4()
  const expiresAt = addDays(new Date(), env.JWT_REFRESH_EXPIRES_DAYS)

  await app.prisma.refreshToken.create({
    data: {
      token: rawRefreshToken,
      userId,
      expiresAt,
    },
  })

  return { accessToken, refreshToken: rawRefreshToken }
}
