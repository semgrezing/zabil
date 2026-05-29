import { FastifyInstance } from 'fastify'
import { errors } from '../../utils/errors.js'
import { requireGroupMember } from '../../middleware/auth.js'
import {
  notifyNewGroupMessage,
  notifyNewPersonalMessage,
} from '../notifications/service.js'
import { isOnline, sendToUser } from './wsHub.js'

// ─── Group / Note chat ─────────────────────────────────────────────────────

export async function getGroupMessages(
  app: FastifyInstance,
  userId: string,
  groupId: string,
  opts: { noteId?: string; limit?: number; before?: string },
) {
  const member = await requireGroupMember(app, userId, groupId)
  if (!member) throw errors.forbidden()
  const limit = Math.min(Math.max(opts.limit ?? 50, 1), 200)
  return app.prisma.groupChatMessage.findMany({
    where: {
      groupId,
      ...(opts.noteId !== undefined && opts.noteId !== null ? { noteId: opts.noteId } : {}),
      ...(opts.before ? { id: { lt: opts.before } } : {}),
    },
    include: {
      sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      note: { select: { id: true, title: true, colorLabel: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
  })
}

export async function sendGroupMessage(
  app: FastifyInstance,
  senderId: string,
  groupId: string,
  body: {
    body?: string
    noteId?: string
    imageUrl?: string
    imageMimeType?: string
    imageSize?: number
    imageCompressed?: boolean
  },
) {
  const hasText = Boolean(body.body && body.body.trim().length > 0)
  const hasImage = Boolean(body.imageUrl)
  if (!hasText && !hasImage) {
    throw errors.badRequest('Пустое сообщение')
  }
  const member = await requireGroupMember(app, senderId, groupId)
  if (!member) throw errors.forbidden()

  if (body.noteId) {
    // Проверяем что заметка действительно из этой группы
    const note = await app.prisma.note.findFirst({
      where: { id: body.noteId, groupId, deletedAt: null },
      select: { id: true },
    })
    if (!note) throw errors.notFound('Заметка')
  }

  const message = await app.prisma.groupChatMessage.create({
    data: {
      groupId,
      senderId,
      noteId: body.noteId ?? null,
      body: hasText ? body.body!.trim().slice(0, 4000) : '',
      imageUrl: body.imageUrl ?? null,
      imageMimeType: body.imageMimeType ?? null,
      imageSize: body.imageSize ?? null,
      imageCompressed: hasImage ? body.imageCompressed ?? true : null,
    },
    include: {
      sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      group: { select: { id: true, title: true } },
      note: { select: { id: true, title: true, colorLabel: true } },
    },
  })

  // WS broadcast всем members кроме sender
  const members = await app.prisma.groupMember.findMany({
    where: { groupId, userId: { not: senderId } },
    select: { userId: true },
  })
  const wsPayload = {
    type: 'message',
    kind: 'group',
    data: {
      id: message.id,
      groupId: message.groupId,
      senderId: message.senderId,
      sender: message.sender,
      noteId: message.noteId,
      note: message.note,
      body: message.body,
      imageUrl: message.imageUrl,
      imageMimeType: message.imageMimeType,
      imageSize: message.imageSize,
      imageCompressed: message.imageCompressed,
      createdAt: message.createdAt.toISOString(),
    },
  }
  members.forEach((m) => sendToUser(m.userId, wsPayload))

  // Push для тех кто offline
  notifyNewGroupMessage(
    app,
    {
      id: message.id,
      groupId: message.groupId,
      senderId: message.senderId,
      body: message.body || '[Изображение]',
      noteId: message.noteId,
    },
    message.sender.username,
    message.group.title,
    isOnline,
  ).catch((e: unknown) => console.error('[notify] notifyNewGroupMessage:', e))

  return message
}

// ─── Personal chats ────────────────────────────────────────────────────────

export async function getPersonalMessages(
  app: FastifyInstance,
  userId: string,
  otherUserId: string,
  opts: { limit?: number; before?: string },
) {
  const limit = Math.min(Math.max(opts.limit ?? 50, 1), 200)
  return app.prisma.personalMessage.findMany({
    where: {
      OR: [
        { senderId: userId, receiverId: otherUserId },
        { senderId: otherUserId, receiverId: userId },
      ],
      ...(opts.before ? { id: { lt: opts.before } } : {}),
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
  })
}

export async function sendPersonalMessage(
  app: FastifyInstance,
  senderId: string,
  receiverId: string,
  payload: {
    body?: string
    imageUrl?: string
    imageMimeType?: string
    imageSize?: number
    imageCompressed?: boolean
  },
) {
  if (senderId === receiverId) throw errors.badRequest('Нельзя писать самому себе')

  const hasText = Boolean(payload.body && payload.body.trim().length > 0)
  const hasImage = Boolean(payload.imageUrl)
  if (!hasText && !hasImage) throw errors.badRequest('Пустое сообщение')

  const receiver = await app.prisma.user.findUnique({ where: { id: receiverId } })
  if (!receiver) throw errors.notFound('Пользователь')

  const message = await app.prisma.personalMessage.create({
    data: {
      senderId,
      receiverId,
      body: hasText ? payload.body!.trim().slice(0, 4000) : '',
      imageUrl: payload.imageUrl ?? null,
      imageMimeType: payload.imageMimeType ?? null,
      imageSize: payload.imageSize ?? null,
      imageCompressed: hasImage ? payload.imageCompressed ?? true : null,
    },
  })

  const sender = await app.prisma.user.findUnique({
    where: { id: senderId },
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  })

  const wsPayload = {
    type: 'message',
    kind: 'personal',
    data: {
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      sender,
      body: message.body,
      imageUrl: message.imageUrl,
      imageMimeType: message.imageMimeType,
      imageSize: message.imageSize,
      imageCompressed: message.imageCompressed,
      readAt: message.readAt?.toISOString() ?? null,
      createdAt: message.createdAt.toISOString(),
    },
  }
  sendToUser(receiverId, wsPayload)
  sendToUser(senderId, wsPayload) // echo на другие устройства sender

  notifyNewPersonalMessage(
    app,
    {
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      body: message.body || '[Изображение]',
    },
    sender?.username ?? 'Пользователь',
    isOnline,
  ).catch((e: unknown) => console.error('[notify] notifyNewPersonalMessage:', e))

  return message
}

export async function getPersonalConversations(app: FastifyInstance, userId: string) {
  // Получаем всех собеседников через массовый запрос + агрегируем последнее сообщение
  const messages = await app.prisma.personalMessage.findMany({
    where: { OR: [{ senderId: userId }, { receiverId: userId }] },
    orderBy: { createdAt: 'desc' },
    take: 1000,
  })
  // Группируем по otherUserId
  const conversations = new Map<
    string,
    { otherUserId: string; lastMessage: any; unreadCount: number }
  >()
  for (const m of messages) {
    const other = m.senderId === userId ? m.receiverId : m.senderId
    let conv = conversations.get(other)
    if (!conv) {
      conv = { otherUserId: other, lastMessage: m, unreadCount: 0 }
      conversations.set(other, conv)
    }
    if (m.receiverId === userId && !m.readAt) {
      conv.unreadCount += 1
    }
  }
  // Подтянем username'ы
  const userIds = Array.from(conversations.keys())
  if (userIds.length === 0) return []
  const users = await app.prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, username: true, displayName: true, avatarUrl: true },
  })
  const userMap = new Map(users.map((u) => [u.id, u]))
  return Array.from(conversations.values()).map((c) => ({
    user: {
      id: c.otherUserId,
      username: userMap.get(c.otherUserId)?.username ?? '?',
      displayName: userMap.get(c.otherUserId)?.displayName ?? null,
      avatarUrl: userMap.get(c.otherUserId)?.avatarUrl ?? null,
    },
    lastMessage: c.lastMessage,
    unreadCount: c.unreadCount,
  }))
}

export async function markPersonalRead(
  app: FastifyInstance,
  userId: string,
  otherUserId: string,
) {
  await app.prisma.personalMessage.updateMany({
    where: { senderId: otherUserId, receiverId: userId, readAt: null },
    data: { readAt: new Date() },
  })
}
