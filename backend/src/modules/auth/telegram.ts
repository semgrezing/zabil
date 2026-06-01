import crypto from 'crypto'
import { FastifyInstance } from 'fastify'
import { issueTokens } from './service.js'

export interface TelegramLoginData {
  id: number
  first_name: string
  last_name?: string
  username?: string
  photo_url?: string
  auth_date: number
  hash: string
}

export interface TelegramProfileData {
  id: string
  username?: string
  firstName?: string
  lastName?: string
  displayName?: string
  photoUrl?: string
}

/**
 * Verify Telegram Login Widget data.
 * See: https://core.telegram.org/widgets/login#checking-authorization
 */
export function verifyTelegramLogin(data: TelegramLoginData, botToken: string): boolean {
  if (!botToken) return false

  const { hash, ...rest } = data
  const checkString = Object.entries(rest)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join('\n')

  const secretKey = crypto.createHash('sha256').update(botToken).digest()
  const hmac = crypto.createHmac('sha256', secretKey).update(checkString).digest('hex')

  if (hmac !== hash) return false

  // Reject stale auth (older than 1 day)
  const ageSec = Math.floor(Date.now() / 1000) - data.auth_date
  if (ageSec > 86_400) return false

  return true
}

function resolveDisplayName(profile: TelegramProfileData): string {
  const explicit = profile.displayName?.trim()
  if (explicit) return explicit
  return [profile.firstName, profile.lastName].filter(Boolean).join(' ').trim()
}

/**
 * Upsert user by telegramId and issue tokens.
 */
export async function loginWithTelegramProfile(app: FastifyInstance, profile: TelegramProfileData) {
  const telegramId = String(profile.id)
  const displayName = resolveDisplayName(profile)

  // Try to find existing user by telegramId
  let user = await app.prisma.user.findUnique({ where: { telegramId } })

  if (!user) {
    // Create new user from Telegram data
    const baseUsername = profile.username ?? `tg_${telegramId}`
    let username = baseUsername
    let attempt = 0
    while (await app.prisma.user.findUnique({ where: { username } })) {
      attempt++
      username = `${baseUsername}_${attempt}`
    }

    user = await app.prisma.user.create({
      data: {
        username,
        passwordHash: '', // No password for Telegram-only accounts
        displayName: displayName || null,
        avatarUrl: profile.photoUrl ?? null,
        telegramId,
      },
    })
  } else {
    // Update display name / avatar if changed
    user = await app.prisma.user.update({
      where: { id: user.id },
      data: {
        displayName: displayName || user.displayName,
        avatarUrl: profile.photoUrl ?? user.avatarUrl,
      },
    })
  }

  const tokens = await issueTokens(app, user.id, user.username)

  return {
    user: {
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    },
    ...tokens,
  }
}

/**
 * Legacy Telegram Login Widget payload (hash-signed fields).
 */
export async function loginWithTelegram(app: FastifyInstance, data: TelegramLoginData) {
  return loginWithTelegramProfile(app, {
    id: String(data.id),
    username: data.username,
    firstName: data.first_name,
    lastName: data.last_name,
    photoUrl: data.photo_url,
  })
}
