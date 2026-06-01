import { FastifyInstance } from 'fastify'
import { getMentions, markMentionsRead } from './service.js'

export async function mentionsRoutes(app: FastifyInstance) {
  app.get('/', async (req) => {
    const user = (req as any).user as { id: string }
    return getMentions(app, user.id)
  })

  app.post('/read-all', async (req) => {
    const user = (req as any).user as { id: string }
    await markMentionsRead(app, user.id)
    return { ok: true }
  })
}
