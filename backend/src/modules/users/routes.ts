import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { updateProfileSchema } from './schema.js'
import {
  getMe,
  getUserPublicProfile,
  updateProfile,
  uploadAvatar,
  getAvatarHistory,
  deleteAvatar,
  deleteAvatarHistoryItem,
  computeIsOnline,
} from './service.js'
import { AppError } from '../../utils/errors.js'
import { env } from '../../config/env.js'

export async function usersRoutes(app: FastifyInstance) {
  // GET /users/me
  app.get('/me', { preHandler: [authenticate] }, async (request, reply) => {
    try {
      const user = await getMe(app, request.user.userId)
      return reply.send(user)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /users/me
  app.patch('/me', { preHandler: [authenticate] }, async (request, reply) => {
    const result = updateProfileSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const user = await updateProfile(app, request.user.userId, result.data)
      return reply.send(user)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /users/me/avatar
  app.post('/me/avatar', { preHandler: [authenticate] }, async (request, reply) => {
    const data = await request.file({
      limits: { fileSize: env.MAX_UPLOAD_SIZE },
    })

    if (!data) {
      return reply.status(400).send({ error: 'Файл не загружен', code: 'VALIDATION_ERROR' })
    }

    try {
      const user = await uploadAvatar(app, request.user.userId, {
        filename: data.filename,
        mimetype: data.mimetype,
        file: data.file,
      })
      return reply.send(user)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /users/me/avatar
  app.delete('/me/avatar', { preHandler: [authenticate] }, async (request, reply) => {
    try {
      const result = await deleteAvatar(app, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /users/me/avatar/history
  app.get('/me/avatar/history', { preHandler: [authenticate] }, async (request, reply) => {
    try {
      const history = await getAvatarHistory(app, request.user.userId)
      return reply.send(history)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /users/me/avatar/history/:historyId
  app.delete('/me/avatar/history/:historyId', { preHandler: [authenticate] }, async (request, reply) => {
    const { historyId } = request.params as { historyId: string }
    try {
      const result = await deleteAvatarHistoryItem(app, request.user.userId, historyId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /users/search?username=alex
  app.get('/search', { preHandler: [authenticate] }, async (request, reply) => {
    const { username } = request.query as { username?: string }

    if (!username || username.trim().length === 0) {
      return reply.status(400).send({ error: 'Параметр username обязателен', code: 'VALIDATION_ERROR' })
    }

    const user = await app.prisma.user.findUnique({
      where: { username: username.trim() },
      select: { id: true, username: true, displayName: true, avatarUrl: true },
    })

    if (!user) {
      return reply.status(404).send({ error: 'Пользователь не найден', code: 'NOT_FOUND' })
    }

    return reply.send({ user })
  })

  // GET /users/:id/profile
  app.get('/:id/profile', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const profile = await getUserPublicProfile(app, request.user.userId, id)
      return reply.send(profile)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /users/:id/online-status — lightweight poll for current online status
  app.get('/:id/online-status', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const user = await app.prisma.user.findUnique({
        where: { id },
        select: { id: true, lastSeenAt: true },
      })
      if (!user) return reply.status(404).send({ error: 'Пользователь не найден', code: 'NOT_FOUND' })
      const isOnline = computeIsOnline(user.lastSeenAt)
      return reply.send({ userId: user.id, isOnline, lastSeenAt: user.lastSeenAt?.toISOString() ?? null })
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}
