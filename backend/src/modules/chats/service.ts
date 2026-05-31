import { FastifyInstance } from 'fastify'
import { errors } from '../../utils/errors.js'
import { requireGroupMember } from '../../middleware/auth.js'
import {
  notifyNewGroupMessage,
  notifyNewPersonalMessage,
} from '../notifications/service.js'
import { computeIsOnline } from '../users/service.js'
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
  const messages = await app.prisma.groupChatMessage.findMany({
    where: {
      groupId,
      ...(opts.noteId !== undefined && opts.noteId !== null ? { noteId: opts.noteId } : {}),
      ...(opts.before ? { createdAt: { lt: new Date(opts.before) } } : {}),
    },
    include: {
      sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      note: { select: { id: true, title: true, colorLabel: true } },
      reads: { select: { userId: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
  })
  return messages.map((m) => ({
    ...m,
    readCount: m.reads.filter((r) => r.userId !== m.senderId).length,
    isReadByMe: m.reads.some((r) => r.userId === userId),
    reads: undefined,
  }))
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

  if (body.imageUrl && !body.imageUrl.startsWith('/uploads/')) {
    throw errors.badRequest('Недопустимый imageUrl')
  }

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
      readCount: 0,
      isReadByMe: false,
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
      ...(opts.before ? { createdAt: { lt: new Date(opts.before) } } : {}),
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

  if (payload.imageUrl && !payload.imageUrl.startsWith('/uploads/')) {
    throw errors.badRequest('Недопустимый imageUrl')
  }

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
  // Efficient: get distinct conversation partners with their last message
  // using a raw query to avoid loading 1000 messages.
  const partnerRows = await app.prisma.$queryRaw<
    Array<{ other_id: string; last_msg_id: string; last_created_at: Date }>
  >`
    SELECT DISTINCT ON (other_id) other_id, id AS last_msg_id, created_at AS last_created_at
    FROM (
      SELECT
        CASE WHEN sender_id = ${userId}::uuid THEN receiver_id ELSE sender_id END AS other_id,
        id,
        created_at
      FROM personal_messages
      WHERE sender_id = ${userId}::uuid OR receiver_id = ${userId}::uuid
    ) sub
    ORDER BY other_id, last_created_at DESC
  `

  if (partnerRows.length === 0) return []

  const otherUserIds = partnerRows.map((r) => r.other_id)
  const lastMsgIds = partnerRows.map((r) => r.last_msg_id)

  const [lastMessages, unreadRows, users] = await Promise.all([
    app.prisma.personalMessage.findMany({ where: { id: { in: lastMsgIds } } }),
    app.prisma.personalMessage.groupBy({
      by: ['senderId'],
      where: { receiverId: userId, readAt: null, senderId: { in: otherUserIds } },
      _count: { id: true },
    }),
    app.prisma.user.findMany({
      where: { id: { in: otherUserIds } },
      select: { id: true, username: true, displayName: true, avatarUrl: true },
    }),
  ])

  const msgMap = new Map(lastMessages.map((m) => [m.id, m]))
  const unreadMap = new Map(unreadRows.map((r) => [r.senderId, r._count.id]))
  const userMap = new Map(users.map((u) => [u.id, u]))

  return partnerRows
    .map((r) => {
      const lastMessage = msgMap.get(r.last_msg_id)
      if (!lastMessage) return null
      const u = userMap.get(r.other_id)
      return {
        user: {
          id: r.other_id,
          username: u?.username ?? '?',
          displayName: u?.displayName ?? null,
          avatarUrl: u?.avatarUrl ?? null,
        },
        lastMessage,
        unreadCount: unreadMap.get(r.other_id) ?? 0,
      }
    })
    .filter(Boolean)
    .sort(
      (a, b) =>
        new Date(b!.lastMessage.createdAt).getTime() -
        new Date(a!.lastMessage.createdAt).getTime(),
    )
}

export async function markGroupRead(
  app: FastifyInstance,
  userId: string,
  groupId: string,
) {
  const member = await requireGroupMember(app, userId, groupId)
  if (!member) throw errors.forbidden()

  // Find all messages in this group NOT sent by the current user that haven't been read by them yet
  const unreadMessages = await app.prisma.groupChatMessage.findMany({
    where: {
      groupId,
      senderId: { not: userId },
      reads: { none: { userId } },
    },
    select: { id: true, senderId: true },
  })

  if (unreadMessages.length === 0) return

  const readAt = new Date()

  // Bulk upsert reads
  await app.prisma.groupMessageRead.createMany({
    data: unreadMessages.map((m) => ({
      messageId: m.id,
      userId,
      readAt,
    })),
    skipDuplicates: true,
  })

  // Notify each distinct sender that their messages were read
  const senderIds = [...new Set(unreadMessages.map((m) => m.senderId))]
  const messageIdsBySender = new Map<string, string[]>()
  for (const m of unreadMessages) {
    const list = messageIdsBySender.get(m.senderId) ?? []
    list.push(m.id)
    messageIdsBySender.set(m.senderId, list)
  }

  for (const senderId of senderIds) {
    const payload = {
      type: 'read_receipt',
      kind: 'group',
      data: {
        groupId,
        readerId: userId,
        messageIds: messageIdsBySender.get(senderId) ?? [],
        readAt: readAt.toISOString(),
      },
    }
    sendToUser(senderId, payload)
  }
  // Also echo to the reader's own devices so other sessions update
  sendToUser(userId, {
    type: 'read_receipt',
    kind: 'group',
    data: {
      groupId,
      readerId: userId,
      messageIds: unreadMessages.map((m) => m.id),
      readAt: readAt.toISOString(),
    },
  })
}

export async function markPersonalRead(
  app: FastifyInstance,
  userId: string,
  otherUserId: string,
) {
  const unread = await app.prisma.personalMessage.findMany({
    where: { senderId: otherUserId, receiverId: userId, readAt: null },
    select: { id: true },
  })
  if (unread.length === 0) return

  const readAt = new Date()
  await app.prisma.personalMessage.updateMany({
    where: { senderId: otherUserId, receiverId: userId, readAt: null },
    data: { readAt },
  })

  const payload = {
    type: 'read_receipt',
    kind: 'personal',
    data: {
      readerId: userId,
      peerUserId: otherUserId,
      messageIds: unread.map((m) => m.id),
      readAt: readAt.toISOString(),
    },
  }

  // Sender gets explicit read receipts, reader updates own devices too.
  sendToUser(otherUserId, payload)
  sendToUser(userId, payload)
}

export async function markGroupRead(
  _app: FastifyInstance,
  _userId: string,
  _groupId: string,
) {
  // Group read receipts not yet implemented in this version
  // TODO: implement when GroupMessageRead model is added
}

const DELETE_WINDOW_MS = 15 * 60 * 1000 // 15 minutes

export async function deleteGroupMessage(
  app: FastifyInstance,
  userId: string,
  groupId: string,
  messageId: string,
) {
  const member = await requireGroupMember(app, userId, groupId)
  if (!member) throw errors.forbidden()

  const message = await app.prisma.groupChatMessage.findFirst({
    where: { id: messageId, groupId, deletedAt: null },
  })
  if (!message) throw errors.notFound('Сообщение')
  if (message.senderId !== userId) throw errors.forbidden()
  if (Date.now() - message.createdAt.getTime() > DELETE_WINDOW_MS) {
    throw errors.badRequest('Сообщение можно удалить только в течение 15 минут')
  }

  const updated = await app.prisma.groupChatMessage.update({
    where: { id: messageId },
    data: { deletedAt: new Date(), body: '', imageUrl: null },
  })

  // Broadcast deletion event to group members
  const members = await app.prisma.groupMember.findMany({
    where: { groupId },
    select: { userId: true },
  })
  const wsPayload = {
    type: 'message_deleted',
    kind: 'group',
    data: { id: messageId, groupId },
  }
  members.forEach((m) => sendToUser(m.userId, wsPayload))

  return updated
}

export async function deletePersonalMessage(
  app: FastifyInstance,
  userId: string,
  otherUserId: string,
  messageId: string,
) {
  const message = await app.prisma.personalMessage.findFirst({
    where: {
      id: messageId,
      OR: [
        { senderId: userId, receiverId: otherUserId },
        { senderId: otherUserId, receiverId: userId },
      ],
      deletedAt: null,
    },
  })
  if (!message) throw errors.notFound('Сообщение')
  if (message.senderId !== userId) throw errors.forbidden()
  if (Date.now() - message.createdAt.getTime() > DELETE_WINDOW_MS) {
    throw errors.badRequest('Сообщение можно удалить только в течение 15 минут')
  }

  const updated = await app.prisma.personalMessage.update({
    where: { id: messageId },
    data: { deletedAt: new Date(), body: '', imageUrl: null },
  })

  const wsPayload = {
    type: 'message_deleted',
    kind: 'personal',
    data: { id: messageId, senderId: userId, receiverId: otherUserId },
  }
  sendToUser(userId, wsPayload)
  sendToUser(otherUserId, wsPayload)

  return updated
}
