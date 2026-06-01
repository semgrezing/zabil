import crypto from 'crypto'
import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { registerSchema, loginSchema, refreshSchema } from './schema.js'
import { registerUser, loginUser, refreshTokens, logoutUser } from './service.js'
import { authenticate } from '../../middleware/auth.js'
import { AppError } from '../../utils/errors.js'
import { verifyTelegramLogin, loginWithTelegram, loginWithTelegramProfile } from './telegram.js'
import { env } from '../../config/env.js'

const telegramSchema = z.object({
  id: z.number().int().positive(),
  first_name: z.string().min(1),
  last_name: z.string().optional(),
  username: z.string().optional(),
  photo_url: z.string().url().optional(),
  auth_date: z.number().int().positive(),
  hash: z.string().length(64),
})

const telegramOidcCallbackSchema = z.object({
  code: z.string().min(1).optional(),
  state: z.string().min(1).optional(),
  error: z.string().optional(),
  error_description: z.string().optional(),
})

interface TelegramOidcTokenResponse {
  access_token?: string
  token_type?: string
  expires_in?: number
  id_token?: string
}

const TELEGRAM_OAUTH_ISSUER = 'https://oauth.telegram.org'
const TELEGRAM_STATE_TTL_MS = 10 * 60 * 1000

function parseTelegramBotId(botToken: string): string | null {
  const [botId] = botToken.split(':')
  if (!botId || !/^\d+$/.test(botId)) return null
  return botId
}

function getTelegramClientId(): string | null {
  const explicitClientId = env.TELEGRAM_CLIENT_ID.trim()
  if (explicitClientId && /^\d+$/.test(explicitClientId)) {
    return explicitClientId
  }
  return parseTelegramBotId(env.TELEGRAM_BOT_TOKEN)
}

function getTelegramClientSecret(): string | null {
  const secret = env.TELEGRAM_CLIENT_SECRET.trim()
  return secret || null
}

function buildTelegramAppRedirect(params: Record<string, string | undefined>) {
  const url = new URL(env.TELEGRAM_APP_REDIRECT_URI)
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') {
      url.searchParams.set(key, value)
    }
  }
  return url.toString()
}

function buildTelegramState(): string {
  const payload = Buffer.from(JSON.stringify({
    nonce: crypto.randomBytes(16).toString('hex'),
    issuedAt: Date.now(),
  })).toString('base64url')

  const signature = crypto
    .createHmac('sha256', env.JWT_SECRET)
    .update(payload)
    .digest('base64url')

  return `${payload}.${signature}`
}

function verifyTelegramState(state: string): boolean {
  const parts = state.split('.')
  if (parts.length !== 2) return false

  const [payload, signature] = parts
  const expectedSignature = crypto
    .createHmac('sha256', env.JWT_SECRET)
    .update(payload)
    .digest('base64url')

  const expectedBuffer = Buffer.from(expectedSignature)
  const signatureBuffer = Buffer.from(signature)
  if (expectedBuffer.length !== signatureBuffer.length) return false
  if (!crypto.timingSafeEqual(expectedBuffer, signatureBuffer)) return false

  try {
    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as {
      issuedAt?: number
    }
    if (typeof decoded.issuedAt !== 'number') return false
    const age = Date.now() - decoded.issuedAt
    return age >= 0 && age <= TELEGRAM_STATE_TTL_MS
  } catch {
    return false
  }
}

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  const parts = token.split('.')
  if (parts.length !== 3) return null

  try {
    const payload = Buffer.from(parts[1], 'base64url').toString('utf8')
    const parsed = JSON.parse(payload)
    return typeof parsed === 'object' && parsed !== null
      ? parsed as Record<string, unknown>
      : null
  } catch {
    return null
  }
}

function asStringClaim(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const normalized = value.trim()
    return normalized || undefined
  }

  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value)
  }

  return undefined
}

function audienceContainsClaim(aud: unknown, expected: string): boolean {
  if (typeof aud === 'string') return aud === expected
  if (Array.isArray(aud)) {
    return aud.some((entry) => typeof entry === 'string' && entry === expected)
  }
  return false
}

export async function authRoutes(app: FastifyInstance) {
  // POST /auth/register
  app.post('/register', async (request, reply) => {
    const result = registerSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({
        error: result.error.errors[0].message,
        code: 'VALIDATION_ERROR',
      })
    }

    try {
      const data = await registerUser(app, result.data)
      return reply.status(201).send(data)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })

  // POST /auth/login
  app.post('/login', async (request, reply) => {
    const result = loginSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({
        error: result.error.errors[0].message,
        code: 'VALIDATION_ERROR',
      })
    }

    try {
      const data = await loginUser(app, result.data)
      return reply.send(data)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })

  // POST /auth/refresh
  app.post('/refresh', async (request, reply) => {
    const result = refreshSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: 'refreshToken обязателен', code: 'VALIDATION_ERROR' })
    }

    try {
      const data = await refreshTokens(app, result.data.refreshToken)
      return reply.send(data)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })

  // POST /auth/logout
  app.post('/logout', { preHandler: [authenticate] }, async (request, reply) => {
    const result = refreshSchema.safeParse(request.body)
    if (result.success) {
      await logoutUser(app, result.data.refreshToken)
    }
    return reply.send({ success: true })
  })

  // GET /auth/telegram/start — redirect user to Telegram OAuth page
  app.get('/telegram/start', async (_request, reply) => {
    const clientId = getTelegramClientId()
    const clientSecret = getTelegramClientSecret()

    if (!clientId || !clientSecret) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'not_configured',
        error_description: 'Telegram Login 2.0 не настроен на сервере',
      }))
    }

    const callbackUrl = new URL('/api/v1/auth/telegram/callback', env.PUBLIC_ORIGIN)
    const oauthUrl = new URL('https://oauth.telegram.org/auth')
    oauthUrl.searchParams.set('client_id', clientId)
    oauthUrl.searchParams.set('redirect_uri', callbackUrl.toString())
    oauthUrl.searchParams.set('response_type', 'code')
    oauthUrl.searchParams.set('scope', 'openid profile')
    oauthUrl.searchParams.set('state', buildTelegramState())

    return reply.redirect(oauthUrl.toString())
  })

  // GET /auth/telegram/callback — Telegram OIDC callback (authorization code)
  app.get('/telegram/callback', async (request, reply) => {
    const parsed = telegramOidcCallbackSchema.safeParse(request.query)
    if (!parsed.success) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'validation_error',
        error_description: 'Telegram вернул неполные данные',
      }))
    }

    if (parsed.data.error) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'oauth_error',
        error_description: parsed.data.error_description ?? parsed.data.error,
      }))
    }

    if (!parsed.data.code || !parsed.data.state) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'validation_error',
        error_description: 'Telegram не вернул код авторизации',
      }))
    }

    if (!verifyTelegramState(parsed.data.state)) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'invalid_state',
        error_description: 'Сессия авторизации устарела. Попробуйте снова',
      }))
    }

    const clientId = getTelegramClientId()
    const clientSecret = getTelegramClientSecret()
    if (!clientId || !clientSecret) {
      return reply.redirect(buildTelegramAppRedirect({
        error: 'not_configured',
        error_description: 'Telegram Login 2.0 не настроен на сервере',
      }))
    }

    const callbackUrl = new URL('/api/v1/auth/telegram/callback', env.PUBLIC_ORIGIN)

    try {
      const tokenResponse = await fetch('https://oauth.telegram.org/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
        },
        signal: AbortSignal.timeout(10_000),
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          code: parsed.data.code,
          redirect_uri: callbackUrl.toString(),
          client_id: clientId,
        }).toString(),
      })

      if (!tokenResponse.ok) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_exchange_failed',
          error_description: `Telegram token endpoint error (${tokenResponse.status})`,
        }))
      }

      const tokens = await tokenResponse.json() as TelegramOidcTokenResponse
      const idToken = tokens.id_token
      if (!idToken) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_invalid',
          error_description: 'Telegram не вернул id_token',
        }))
      }

      const claims = decodeJwtPayload(idToken)
      if (!claims) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_invalid',
          error_description: 'Не удалось прочитать id_token',
        }))
      }

      if (claims.iss !== TELEGRAM_OAUTH_ISSUER) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_issuer',
          error_description: 'Неверный issuer в id_token',
        }))
      }

      if (!audienceContainsClaim(claims.aud, clientId)) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_audience',
          error_description: 'Неверный audience в id_token',
        }))
      }

      const exp = typeof claims.exp === 'number' ? claims.exp : NaN
      if (!Number.isFinite(exp) || exp <= Math.floor(Date.now() / 1000)) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_expired',
          error_description: 'Сессия Telegram истекла. Попробуйте снова',
        }))
      }

      const telegramId = asStringClaim(claims.sub)
      if (!telegramId) {
        return reply.redirect(buildTelegramAppRedirect({
          error: 'token_invalid',
          error_description: 'В id_token отсутствует идентификатор пользователя',
        }))
      }

      const data = await loginWithTelegramProfile(app, {
        id: telegramId,
        username: asStringClaim(claims.preferred_username) ?? asStringClaim(claims.username),
        firstName: asStringClaim(claims.given_name),
        lastName: asStringClaim(claims.family_name),
        displayName: asStringClaim(claims.name),
        photoUrl: asStringClaim(claims.picture),
      })

      return reply.redirect(buildTelegramAppRedirect({
        accessToken: data.accessToken,
        refreshToken: data.refreshToken,
      }))
    } catch (err) {
      if (err instanceof AppError) {
        return reply.redirect(buildTelegramAppRedirect({
          error: err.code ?? 'auth_error',
          error_description: err.message,
        }))
      }

      app.log.error({ err }, 'Telegram token exchange failed')
      return reply.redirect(buildTelegramAppRedirect({
        error: 'telegram_unreachable',
        error_description: 'Сервер не может подключиться к Telegram OAuth (oauth.telegram.org:443)',
      }))
    }
  })

  app.post('/telegram', async (request, reply) => {
    const result = telegramSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({
        error: result.error.errors[0]?.message ?? 'Ошибка валидации',
        code: 'VALIDATION_ERROR',
      })
    }

    if (!env.TELEGRAM_BOT_TOKEN) {
      return reply.status(503).send({ error: 'Telegram OAuth не настроен', code: 'NOT_CONFIGURED' })
    }

    if (!verifyTelegramLogin(result.data, env.TELEGRAM_BOT_TOKEN)) {
      return reply.status(401).send({ error: 'Неверная подпись Telegram', code: 'INVALID_HASH' })
    }

    try {
      const data = await loginWithTelegram(app, result.data)
      return reply.send(data)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })
}
