import { FastifyInstance } from 'fastify'
import { registerSchema, loginSchema, refreshSchema } from './schema.js'
import { registerUser, loginUser, refreshTokens, logoutUser } from './service.js'
import { authenticate } from '../../middleware/auth.js'
import { AppError } from '../../utils/errors.js'

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
}
