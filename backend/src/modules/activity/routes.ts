import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { getActivityFeed } from './service.js'

export async function activityRoutes(app: FastifyInstance) {
  // GET /activity/feed?limit=50
  app.get('/feed', { preHandler: [authenticate] }, async (request, reply) => {
    const { limit } = request.query as { limit?: string }
    const parsedLimit = Math.min(parseInt(limit ?? '50', 10) || 50, 100)
    try {
      const feed = await getActivityFeed(app, request.user.userId, parsedLimit)
      return reply.send(feed)
    } catch (err) {
      app.log.error({ err, userId: request.user.userId }, 'activity feed failed')
      throw err
    }
  })
}
