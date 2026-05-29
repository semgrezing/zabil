import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { registerDevice, unregisterDevice } from './service.js'
import { AppError } from '../../utils/errors.js'

export async function notificationsRoutes(app: FastifyInstance) {
  // POST /devices/register
  app.post('/register', { preHandler: [authenticate] }, async (request, reply) => {
    const body = request.body as { platform?: string; token?: string }
    if (!body?.platform || !body?.token) {
      return reply.status(400).send({ error: 'platform и token обязательны', code: 'VALIDATION_ERROR' })
    }
    try {
      const dt = await registerDevice(app, request.user.userId, body.platform, body.token)
      return reply.status(201).send(dt)
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })

  // DELETE /devices/:tokenId
  app.delete('/:tokenId', { preHandler: [authenticate] }, async (request, reply) => {
    const { tokenId } = request.params as { tokenId: string }
    try {
      await unregisterDevice(app, request.user.userId, tokenId)
      return reply.status(204).send()
    } catch (err) {
      if (err instanceof AppError) return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      throw err
    }
  })
}
