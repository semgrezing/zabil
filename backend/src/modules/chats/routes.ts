import { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { authenticate } from '../../middleware/auth.js'
import {
  getGroupMessages,
  sendGroupMessage,
  markGroupRead,
  getPersonalMessages,
  sendPersonalMessage,
  getPersonalConversations,
  markPersonalRead,
  deleteGroupMessage,
  deletePersonalMessage,
} from './service.js'
import { AppError } from '../../utils/errors.js'

const sendGroupMessageSchema = z.object({
  body: z.string().max(4000).optional(),
  noteId: z.string().uuid().optional(),
  imageUrl: z.string().startsWith('/uploads/').optional(),
  imageMimeType: z.string().max(100).optional(),
  imageSize: z.number().int().positive().max(52_428_800).optional(),
  imageCompressed: z.boolean().optional(),
}).refine((d) => d.body || d.imageUrl, 'body или imageUrl обязателен')

const sendPersonalMessageSchema = z.object({
  body: z.string().max(4000).optional(),
  imageUrl: z.string().startsWith('/uploads/').optional(),
  imageMimeType: z.string().max(100).optional(),
  imageSize: z.number().int().positive().max(52_428_800).optional(),
  imageCompressed: z.boolean().optional(),
}).refine((d) => d.body || d.imageUrl, 'body или imageUrl обязателен')

export async function chatsRoutes(app: FastifyInstance) {
  // ─── Group / note chat ───────────────────────────────────────────────────
  app.get(
    '/groups/:groupId/messages',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { groupId } = request.params as { groupId: string }
      const q = request.query as { noteId?: string; limit?: string; before?: string }
      try {
        const messages = await getGroupMessages(app, request.user.userId, groupId, {
          noteId: q.noteId,
          limit: q.limit ? parseInt(q.limit, 10) : undefined,
          before: q.before,
        })
        return reply.send(messages)
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.post(
    '/groups/:groupId/messages',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { groupId } = request.params as { groupId: string }
      const parsed = sendGroupMessageSchema.safeParse(request.body)
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.errors[0]?.message ?? 'Ошибка валидации',
          code: 'VALIDATION_ERROR',
        })
      }
      const body = parsed.data
      try {
        const message = await sendGroupMessage(app, request.user.userId, groupId, {
          body: body.body,
          noteId: body.noteId,
          imageUrl: body.imageUrl,
          imageMimeType: body.imageMimeType,
          imageSize: body.imageSize,
          imageCompressed: body.imageCompressed,
        })
        return reply.status(201).send(message)
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.post(
    '/groups/:groupId/read',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { groupId } = request.params as { groupId: string }
      try {
        await markGroupRead(app, request.user.userId, groupId)
        return reply.status(204).send()
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.delete(
    '/groups/:groupId/messages/:messageId',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { groupId, messageId } = request.params as { groupId: string; messageId: string }
      try {
        await deleteGroupMessage(app, request.user.userId, groupId, messageId)
        return reply.status(204).send()
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  // ─── Personal chats ─────────────────────────────────────────────────────
  app.get('/personal', { preHandler: [authenticate] }, async (request, reply) => {
    const list = await getPersonalConversations(app, request.user.userId)
    return reply.send(list)
  })

  app.get(
    '/personal/:userId/messages',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { userId } = request.params as { userId: string }
      const q = request.query as { limit?: string; before?: string }
      try {
        const messages = await getPersonalMessages(app, request.user.userId, userId, {
          limit: q.limit ? parseInt(q.limit, 10) : undefined,
          before: q.before,
        })
        return reply.send(messages)
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.post(
    '/personal/:userId/messages',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { userId } = request.params as { userId: string }
      const parsed = sendPersonalMessageSchema.safeParse(request.body)
      if (!parsed.success) {
        return reply.status(400).send({
          error: parsed.error.errors[0]?.message ?? 'Ошибка валидации',
          code: 'VALIDATION_ERROR',
        })
      }
      const body = parsed.data
      try {
        const message = await sendPersonalMessage(
          app,
          request.user.userId,
          userId,
          {
            body: body.body,
            imageUrl: body.imageUrl,
            imageMimeType: body.imageMimeType,
            imageSize: body.imageSize,
            imageCompressed: body.imageCompressed,
          },
        )
        return reply.status(201).send(message)
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.delete(
    '/personal/:userId/messages/:messageId',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { userId, messageId } = request.params as { userId: string; messageId: string }
      try {
        await deletePersonalMessage(app, request.user.userId, userId, messageId)
        return reply.status(204).send()
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )

  app.post(
    '/personal/:userId/read',
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { userId } = request.params as { userId: string }
      try {
        await markPersonalRead(app, request.user.userId, userId)
        return reply.status(204).send()
      } catch (err) {
        if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
        throw err
      }
    },
  )
}
