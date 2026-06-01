import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import {
  createNoteSchema, updateNoteSchema, notesQuerySchema, moveNoteSchema,
  createChecklistItemSchema, updateChecklistItemSchema,
} from './schema.js'
import {
  getNotes, getNoteById, createNote, updateNote, archiveNote, deleteNote,
  moveNote,
  addChecklistItem, updateChecklistItem, deleteChecklistItem,
} from './service.js'
import { blockRoutes } from './block-routes.js'
import { AppError } from '../../utils/errors.js'

export async function notesRoutes(app: FastifyInstance) {
  // Block sub-routes: /notes/:noteId/blocks/*
  app.register(blockRoutes, { prefix: '/:noteId/blocks' })

  // GET /notes
  app.get('/', { preHandler: [authenticate] }, async (request, reply) => {
    const queryResult = notesQuerySchema.safeParse(request.query)
    if (!queryResult.success) {
      return reply.status(400).send({ error: queryResult.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const notes = await getNotes(app, request.user.userId, queryResult.data)
      return reply.send(notes)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /notes/:id
  app.get('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const note = await getNoteById(app, id, request.user.userId)
      return reply.send(note)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /notes
  app.post('/', { preHandler: [authenticate] }, async (request, reply) => {
    const result = createNoteSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const note = await createNote(app, request.user.userId, result.data)
      return reply.status(201).send(note)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /notes/:id
  app.patch('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    const result = updateNoteSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const note = await updateNote(app, id, request.user.userId, result.data)
      return reply.send(note)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /notes/:id/move
  app.patch('/:id/move', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    const result = moveNoteSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const note = await moveNote(app, id, request.user.userId, result.data)
      return reply.send(note)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /notes/:id (soft)
  app.delete('/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await deleteNote(app, id, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /notes/:id/archive
  app.post('/:id/archive', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await archiveNote(app, id, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /notes/:id/checklist
  app.post('/:id/checklist', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    const result = createChecklistItemSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const item = await addChecklistItem(app, id, request.user.userId, result.data)
      return reply.status(201).send(item)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // PATCH /notes/:id/checklist/:itemId
  app.patch('/:id/checklist/:itemId', { preHandler: [authenticate] }, async (request, reply) => {
    const { id, itemId } = request.params as { id: string; itemId: string }
    const result = updateChecklistItemSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }
    try {
      const item = await updateChecklistItem(app, id, itemId, request.user.userId, result.data)
      return reply.send(item)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /notes/:id/checklist/:itemId
  app.delete('/:id/checklist/:itemId', { preHandler: [authenticate] }, async (request, reply) => {
    const { id, itemId } = request.params as { id: string; itemId: string }
    try {
      const result = await deleteChecklistItem(app, id, itemId, request.user.userId)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}
