import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { registerSchema, loginSchema, refreshSchema } from './schema.js'
import { registerUser, loginUser, refreshTokens, logoutUser } from './service.js'
import { authenticate } from '../../middleware/auth.js'
import { AppError } from '../../utils/errors.js'
import { verifyTelegramLogin, loginWithTelegram } from './telegram.js'
import { env } from '../../config/env.js'

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

  // POST /auth/telegram — Telegram Login Widget
  const telegramSchema = z.object({
    id: z.number().int().positive(),
    first_name: z.string().min(1),
    last_name: z.string().optional(),
    username: z.string().optional(),
    photo_url: z.string().url().optional(),
    auth_date: z.number().int().positive(),
    hash: z.string().length(64),
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
