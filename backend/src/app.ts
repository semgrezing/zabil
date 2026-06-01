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
import { mentionsRoutes } from './modules/mentions/routes.js'
import {
  addConnection, removeConnection,
  joinNote, leaveNote, leaveAllNotes, broadcastToNote,
  sendToUser, broadcastOnlineStatus,
} from './modules/chats/wsHub.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function ensureDir(dir: string) {
  try {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true })
  } catch (e) {
    console.warn('[bootstrap] не удалось создать', dir, e)
  }
}

function sanitizeDownloadFileName(fileName: string) {
  return fileName.replace(/["\r\n]/g, '_')
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
    max: 300,
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
    setHeaders: (res, filePath) => {
      const fileName = sanitizeDownloadFileName(path.basename(filePath))
      const ext = path.extname(fileName).toLowerCase()

      if (ext === '.apk') {
        res.setHeader('Content-Type', 'application/vnd.android.package-archive')
      } else if (ext === '.exe') {
        res.setHeader('Content-Type', 'application/octet-stream')
      }

      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`)
      res.setHeader('Cache-Control', 'public, max-age=0, no-transform')
      res.setHeader('X-Download-Options', 'noopen')
    },
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
    await api.register(mentionsRoutes, { prefix: '/mentions' })
  }, { prefix: '/api/v1' })

  // WebSocket endpoint: /api/v1/ws?token=<JWT>
  const chatTypingThrottleMs = 900
  const chatTypingLastSentAt = new Map<string, number>()

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

        // Update lastSeenAt and broadcast online status on connect
        const connectTime = new Date()
        app.prisma.user.update({
          where: { id: userId },
          data: { lastSeenAt: connectTime },
        }).catch(() => {})
        broadcastOnlineStatus(userId, true, connectTime)

        // Cache displayName for this connection (resolved lazily once)
        let cachedDisplayName: string | null = null
        async function getDisplayName(): Promise<string> {
          if (cachedDisplayName !== null) return cachedDisplayName
          const user = await app.prisma.user.findUnique({
            where: { id: userId },
            select: { displayName: true, username: true },
          })
          cachedDisplayName = user?.displayName ?? user?.username ?? userId
          return cachedDisplayName
        }

        // ── Incoming message handler ───────────────────────────
        ws.on('message', async (raw: Buffer | string) => {
          try {
            const msg = JSON.parse(typeof raw === 'string' ? raw : raw.toString())

            if (msg.type === 'ping') {
              ws.send(JSON.stringify({ type: 'pong' }))
              const pingTime = new Date()
              app.prisma.user.update({
                where: { id: userId },
                data: { lastSeenAt: pingTime },
              }).catch(() => {})
            } else if (msg.type === 'presence' && msg.noteId) {
              const noteId = msg.noteId as string

              if (msg.action === 'join') {
                const viewers = joinNote(userId, noteId)
                const displayName = await getDisplayName()
                broadcastToNote(noteId, userId, {
                  type: 'presence',
                  noteId,
                  userId,
                  displayName,
                  action: 'join',
                })
                // Send the current viewer list back to the joining user
                ws.send(JSON.stringify({ type: 'presence', noteId, action: 'viewers', viewers }))
              } else if (msg.action === 'leave') {
                leaveNote(userId, noteId)
                const displayName = await getDisplayName()
                broadcastToNote(noteId, userId, {
                  type: 'presence',
                  noteId,
                  userId,
                  displayName,
                  action: 'leave',
                })
              }
            } else if (msg.type === 'typing' && msg.noteId) {
              broadcastToNote(msg.noteId as string, userId, {
                type: 'typing',
                noteId: msg.noteId,
                userId,
              })
            } else if (msg.type === 'chat_typing' || msg.type === 'chat_typing_stop') {
              const isStop = msg.type === 'chat_typing_stop'
              const now = Date.now()
              const kind = msg.kind as string | undefined

              if (kind === 'group' && typeof msg.groupId === 'string') {
                const groupId = msg.groupId as string

                if (!isStop) {
                  const throttleKey = `${userId}:group:${groupId}`
                  const last = chatTypingLastSentAt.get(throttleKey) ?? 0
                  if (now - last < chatTypingThrottleMs) return
                  chatTypingLastSentAt.set(throttleKey, now)
                }

                const member = await app.prisma.groupMember.findUnique({
                  where: { groupId_userId: { groupId, userId } },
                  select: { userId: true },
                })
                if (!member) return

                const members = await app.prisma.groupMember.findMany({
                  where: { groupId, userId: { not: userId } },
                  select: { userId: true },
                })
                const displayName = await getDisplayName()
                const payload = isStop
                  ? {
                      type: 'chat_typing_stop',
                      kind: 'group',
                      data: { groupId, senderId: userId },
                    }
                  : {
                      type: 'chat_typing',
                      kind: 'group',
                      data: { groupId, senderId: userId, displayName },
                    }
                members.forEach((m) => sendToUser(m.userId, payload))
              } else if (kind === 'personal' && typeof msg.userId === 'string') {
                const peerUserId = msg.userId as string

                if (!isStop) {
                  const throttleKey = `${userId}:personal:${peerUserId}`
                  const last = chatTypingLastSentAt.get(throttleKey) ?? 0
                  if (now - last < chatTypingThrottleMs) return
                  chatTypingLastSentAt.set(throttleKey, now)
                }

                const peer = await app.prisma.user.findUnique({
                  where: { id: peerUserId },
                  select: { id: true },
                })
                if (!peer) return

                const displayName = await getDisplayName()
                const payload = isStop
                  ? {
                      type: 'chat_typing_stop',
                      kind: 'personal',
                      data: { userId: peerUserId, senderId: userId },
                    }
                  : {
                      type: 'chat_typing',
                      kind: 'personal',
                      data: { userId: peerUserId, senderId: userId, displayName },
                    }
                sendToUser(peerUserId, payload)
              }
            }
          } catch (_) {
            // Ignore malformed messages
          }
        })

        function handleDisconnect() {
          removeConnection(userId, handle)
          // Broadcast leave for every note this user was viewing
          const leftNotes = leaveAllNotes(userId)
          for (const noteId of leftNotes) {
            broadcastToNote(noteId, userId, {
              type: 'presence',
              noteId,
              userId,
              action: 'leave',
            })
          }
          // Update lastSeenAt and broadcast offline status (only if truly gone)
          const disconnectTime = new Date()
          app.prisma.user.update({
            where: { id: userId },
            data: { lastSeenAt: disconnectTime },
          }).catch(() => {})
          // isOnline check: if no connections remain, broadcast offline
          broadcastOnlineStatus(userId, false, disconnectTime)
        }
        ws.on('close', handleDisconnect)
        ws.on('error', handleDisconnect)
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
