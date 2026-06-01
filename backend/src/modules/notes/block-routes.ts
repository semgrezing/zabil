import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { createBlockSchema, updateBlockSchema, reorderBlocksSchema } from './block-schema.js'
import { createBlock, updateBlock, deleteBlock, reorderBlocks } from './block-service.js'
import { AppError } from '../../utils/errors.js'

export async function blockRoutes(app: FastifyInstance) {
  // POST /notes/:noteId/blocks
  app.post('/', { preHandler: [authenticate] }, async (request, reply) => {
    const { noteId } = request.params as { noteId: string }
    const result = createBlockSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const block = await createBlock(app, noteId, request.user.userId, result.data)
      return reply.status(201).send(block)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /notes/:noteId/blocks/reorder
  app.patch('/reorder', { preHandler: [authenticate] }, async (request, reply) => {
    const { noteId } = request.params as { noteId: string }
    const result = reorderBlocksSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const res = await reorderBlocks(app, noteId, request.user.userId, result.data)
      return reply.send(res)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /notes/:noteId/blocks/:blockId
  app.patch('/:blockId', { preHandler: [authenticate] }, async (request, reply) => {
    const { noteId, blockId } = request.params as { noteId: string; blockId: string }
    const result = updateBlockSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const block = await updateBlock(app, noteId, blockId, request.user.userId, result.data)
      return reply.send(block)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /notes/:noteId/blocks/:blockId
  app.delete('/:blockId', { preHandler: [authenticate] }, async (request, reply) => {
    const { noteId, blockId } = request.params as { noteId: string; blockId: string }
    try {
      const result = await deleteBlock(app, noteId, blockId, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}
