import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import {
  getGroupMessages,
  sendGroupMessage,
  getPersonalMessages,
  sendPersonalMessage,
  getPersonalConversations,
  markPersonalRead,
} from './service.js'
import { AppError } from '../../utils/errors.js'

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
      const body = request.body as {
        body?: string
        noteId?: string
        imageUrl?: string
        imageMimeType?: string
        imageSize?: number
        imageCompressed?: boolean
      }
      if (!body?.body && !body?.imageUrl) {
        return reply.status(400).send({ error: 'body или imageUrl обязателен', code: 'VALIDATION_ERROR' })
      }
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
      const body = request.body as {
        body?: string
        imageUrl?: string
        imageMimeType?: string
        imageSize?: number
        imageCompressed?: boolean
      }
      if (!body?.body && !body?.imageUrl) {
        return reply.status(400).send({ error: 'body или imageUrl обязателен', code: 'VALIDATION_ERROR' })
      }
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
