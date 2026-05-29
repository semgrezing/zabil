import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { createGroupSchema, updateGroupSchema } from './schema.js'
import {
  createGroup,
  getUserGroups,
  getGroupById,
  getPersonalContext,
  updateGroup,
  removeGroupMember,
  uploadGroupAvatar,
  getGroupAvatarHistory,
  deleteGroupAvatar,
  deleteGroupAvatarHistoryItem,
  leaveGroup,
  deleteGroup,
} from './service.js'
import { AppError } from '../../utils/errors.js'
import { env } from '../../config/env.js'

export async function groupsRoutes(app: FastifyInstance) {
  // POST /groups
  app.post('/', { preHandler: [authenticate] }, async (request, reply) => {
    const result = createGroupSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }

    try {
      const group = await createGroup(app, request.user.userId, result.data)
      return reply.status(201).send(group)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /groups
  app.get('/', { preHandler: [authenticate] }, async (request, reply) => {
    const groups = await getUserGroups(app, request.user.userId)
    return reply.send(groups)
  })

  // GET /groups/personal-context
  app.get('/personal-context', { preHandler: [authenticate] }, async (request, reply) => {
    try {
      const personal = await getPersonalContext(app, request.user.userId)
      return reply.send(personal)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /groups/:id
  app.get('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }

    try {
      const group = await getGroupById(app, id, request.user.userId)
      return reply.send(group)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /groups/:id
  app.patch('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    const result = updateGroupSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }

    try {
      const group = await updateGroup(app, id, request.user.userId, result.data)
      return reply.send(group)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /groups/:id/members/:userId
  app.delete('/:id/members/:userId', { preHandler: [authenticate] }, async (request, reply) => {
    const { id, userId } = request.params as { id: string; userId: string }
    try {
      const result = await removeGroupMember(app, id, request.user.userId, userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /groups/:id/avatar
  app.post('/:id/avatar', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    const data = await request.file({
      limits: { fileSize: env.MAX_UPLOAD_SIZE },
    })
    if (!data) {
      return reply.status(400).send({ error: 'Файл не загружен', code: 'VALIDATION_ERROR' })
    }

    try {
      const group = await uploadGroupAvatar(app, id, request.user.userId, {
        filename: data.filename,
        mimetype: data.mimetype,
        file: data.file,
      })
      return reply.send(group)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /groups/:id/avatar
  app.delete('/:id/avatar', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await deleteGroupAvatar(app, id, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /groups/:id/avatar/history
  app.get('/:id/avatar/history', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const history = await getGroupAvatarHistory(app, id, request.user.userId)
      return reply.send(history)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /groups/:id/avatar/history/:historyId
  app.delete('/:id/avatar/history/:historyId', { preHandler: [authenticate] }, async (request, reply) => {
    const { id, historyId } = request.params as { id: string; historyId: string }
    try {
      const result = await deleteGroupAvatarHistoryItem(app, id, request.user.userId, historyId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /groups/:id/leave
  app.delete('/:id/leave', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await leaveGroup(app, id, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /groups/:id — удаление группы (только creator)
  app.delete('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await deleteGroup(app, id, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}