import Fastify from 'fastify'
import cors from '@fastify/cors'
import rateLimit from '@fastify/rate-limit'
import multipart from '@fastify/multipart'
import staticFiles from '@fastify/static'
import websocket from '@fastify/websocket'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

import prismaPlugin from './plugins/prisma.js'
import jwtPlugin from './plugins/jwt.js'
import { env } from './config/env.js'

import { authRoutes } from './modules/auth/routes.js'
import { usersRoutes } from './modules/users/routes.js'
import { groupsRoutes } from './modules/groups/routes.js'
import { invitationsRoutes } from './modules/invitations/routes.js'
import { notesRoutes } from './modules/notes/routes.js'
import { uploadsRoutes } from './modules/uploads/routes.js'
import { updateRoutes } from './modules/update/routes.js'
import { chatsRoutes } from './modules/chats/routes.js'
import { notificationsRoutes } from './modules/notifications/routes.js'
import { activityRoutes } from './modules/activity/routes.js'
import { addConnection, removeConnection } from './modules/chats/wsHub.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function ensureDir(dir: string) {
  try {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
  } catch (e) {
    console.warn('[bootstrap] не удалось создать', dir, e)
  }
}

export async function buildApp() {
  const app = Fastify({
    logger: env.NODE_ENV === 'development'
      ? true
      : { level: 'error' },
  })

  // Security: CORS
  await app.register(cors, {
    origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
    credentials: true,
  })

  // Security: Rate limiting
  await app.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
  })

  // Multipart (file uploads)
  await app.register(multipart)

  // Allow empty JSON bodies for endpoints without payloads.
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body, done) => {
    if (body === '' || body === undefined || body === null) {
      done(null, null)
      return
    }
    try {
      done(null, JSON.parse(body as string))
    } catch (err) {
      done(err as Error)
    }
  })

  // Serve uploaded files statically
  ensureDir(path.resolve(env.UPLOADS_PATH))
  await app.register(staticFiles, {
    root: path.resolve(env.UPLOADS_PATH),
    prefix: '/uploads/',
    decorateReply: false,
  })

  // Serve release artifacts (APK / EXE) statically
  ensureDir(path.resolve(env.RELEASES_PATH))
  await app.register(staticFiles, {
    root: path.resolve(env.RELEASES_PATH),
    prefix: '/releases/',
    decorateReply: false,
  })

  // Core plugins
  await app.register(prismaPlugin)
  await app.register(jwtPlugin)

  // WebSocket plugin (для real-time чатов)
  await app.register(websocket)

  // Health check
  app.get('/health', async () => ({ status: 'ok', version: env.APP_VERSION }))

  // API routes (with auth rate limits)
  await app.register(async (api) => {
    // Stricter rate limit for auth
    await api.register(rateLimit, {
      max: 10,
      timeWindow: '1 minute',
      keyGenerator: (req) => req.ip,
    })

    await api.register(authRoutes, { prefix: '/auth' })
  }, { prefix: '/api/v1' })

  await app.register(async (api) => {
    await api.register(usersRoutes, { prefix: '/users' })
    await api.register(groupsRoutes, { prefix: '/groups' })
    await api.register(invitationsRoutes, { prefix: '/invitations' })
    await api.register(notesRoutes, { prefix: '/notes' })
    await api.register(uploadsRoutes, { prefix: '/uploads' })
    await api.register(updateRoutes, { prefix: '/update' })
    await api.register(chatsRoutes, { prefix: '/chats' })
    await api.register(notificationsRoutes, { prefix: '/devices' })
    await api.register(activityRoutes, { prefix: '/activity' })
  }, { prefix: '/api/v1' })

  // WebSocket endpoint: /api/v1/ws?token=<JWT>
  await app.register(async (wsApi) => {
    wsApi.get('/ws', { websocket: true }, (socket, req) => {
      const ws = socket.socket
      const token = (req.query as { token?: string }).token
      if (!token) {
        ws.close(1008, 'token required')
        return
      }
      try {
        const decoded = app.jwt.verify(token) as { userId: string }
        const userId = decoded.userId
        // Адаптер под наш hub-интерфейс {send, close}
        const handle = {
          send: (data: string) => ws.send(data),
          close: () => ws.close(),
        }
        addConnection(userId, handle)
        ws.send(JSON.stringify({ type: 'hello', userId }))

        ws.on('close', () => removeConnection(userId, handle))
        ws.on('error', () => removeConnection(userId, handle))
      } catch (_) {
        ws.close(1008, 'invalid token')
      }
    })
  }, { prefix: '/api/v1' })

  // Global error handler
  app.setErrorHandler((error, request, reply) => {
    app.log.error({ err: error, url: request.url, method: request.method }, error.message)

    if (error.statusCode === 429) {
      return reply.status(429).send({ error: 'Слишком много запросов', code: 'RATE_LIMIT' })
    }

    const status = error.statusCode ?? 500
    return reply.status(status).send({
      error: status >= 500 ? 'Внутренняя ошибка сервера' : error.message,
      code: status >= 500 ? 'INTERNAL_ERROR' : 'ERROR',
    })
  })

  return app
}
