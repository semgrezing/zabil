import fp from 'fastify-plugin'
import { FastifyPluginAsync } from 'fastify'
import fjwt from '@fastify/jwt'
import { env } from '../config/env.js'

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { userId: string; username: string }
    user: { userId: string; username: string }
  }
}

const jwtPlugin: FastifyPluginAsync = fp(async (app) => {
  app.register(fjwt, {
    secret: env.JWT_SECRET,
  })

  app.decorate('authenticate', async function (request: any, reply: any) {
    try {
      await request.jwtVerify()
    } catch (err) {
      return reply.status(401).send({ error: 'Не авторизован', code: 'UNAUTHORIZED' })
    }
  })
})

export default jwtPlugin
