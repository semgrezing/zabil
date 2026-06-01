import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { getMentions, markMentionsRead } from './service.js'

export async function mentionsRoutes(app: FastifyInstance) {
  app.get('/', { preHandler: [authenticate] }, async (req) => {
    return getMentions(app, req.user.userId)
  })

  app.post('/read-all', { preHandler: [authenticate] }, async (req) => {
    await markMentionsRead(app, req.user.userId)
    return { ok: true }
  })
}
