import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { sendInvitationSchema } from './schema.js'
import {
  sendInvitation,
  getIncomingInvitations,
  getGroupPendingInvitations,
  respondToInvitation,
} from './service.js'
import { AppError } from '../../utils/errors.js'

export async function invitationsRoutes(app: FastifyInstance) {
  // POST /invitations
  app.post('/', { preHandler: [authenticate] }, async (request, reply) => {
    const result = sendInvitationSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: result.error.errors[0].message, code: 'VALIDATION_ERROR' })
    }

    try {
      const invitation = await sendInvitation(app, request.user.userId, result.data)
      return reply.status(201).send(invitation)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // GET /invitations/incoming
  app.get('/incoming', { preHandler: [authenticate] }, async (request, reply) => {
    const invitations = await getIncomingInvitations(app, request.user.userId)
    return reply.send(invitations)
  })

  // GET /invitations/group/:groupId/pending
  app.get('/group/:groupId/pending', { preHandler: [authenticate] }, async (request, reply) => {
    const { groupId } = request.params as { groupId: string }
    try {
      const invitations = await getGroupPendingInvitations(app, request.user.userId, groupId)
      return reply.send(invitations)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /invitations/:id/accept
  app.post('/:id/accept', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await respondToInvitation(app, id, request.user.userId, 'accept')
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // POST /invitations/:id/decline
  app.post('/:id/decline', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string }
    try {
      const result = await respondToInvitation(app, id, request.user.userId, 'decline')
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}
