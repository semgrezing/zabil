import { FastifyInstance } from 'fastify'
import { sendToUser } from '../chats/wsHub.js'
import { sendPush } from '../notifications/service.js'

export function extractMentionedUsernames(text: string): string[] {
  if (!text) return []
  const regex = /(?<!\w)@([a-zA-Z0-9_]+)/g
  const matches = new Set<string>()
  let m
  while ((m = regex.exec(text)) !== null) {
    matches.add(m[1].toLowerCase())
  }
  return Array.from(matches)
}

export function extractTextFromDelta(content: string): string {
  if (!content) return ''
  try {
    const parsed = JSON.parse(content)
    if (Array.isArray(parsed)) {
      return parsed
        .filter((op: any) => typeof op.insert === 'string')
        .map((op: any) => op.insert as string)
        .join('')
    }
  } catch {
    // not delta — return as-is
  }
  return content
}

type MentionContext = 'group_message' | 'personal_message' | 'note'

interface CreateMentionsOptions {
  app: FastifyInstance
  mentionerUserId: string
  usernames: string[]
  context: MentionContext
  groupId?: string
  noteId?: string
  messageId?: string
  dedupByNote?: boolean
}

export async function createMentions(opts: CreateMentionsOptions): Promise<void> {
  const { app, mentionerUserId, usernames, context, groupId, noteId, messageId, dedupByNote } = opts
  if (usernames.length === 0) return

  const users = await app.prisma.user.findMany({
    where: {
      username: { in: usernames, mode: 'insensitive' },
      id: { not: mentionerUserId },
    },
    select: { id: true, username: true },
  })
  if (users.length === 0) return

  const mentioner = await app.prisma.user.findUnique({
    where: { id: mentionerUserId },
    select: { username: true, displayName: true },
  })

  for (const user of users) {
    if (dedupByNote && noteId) {
      const existing = await app.prisma.mention.findFirst({
        where: { mentionedUserId: user.id, context: 'note', noteId },
      })
      if (existing) continue
    }

    const mention = await app.prisma.mention.create({
      data: {
        mentionedUserId: user.id,
        mentionerUserId,
        context,
        groupId: groupId ?? null,
        noteId: noteId ?? null,
        messageId: messageId ?? null,
      },
      include: {
        mentioner: { select: { id: true, username: true, displayName: true } },
        group: { select: { id: true, title: true } },
        note: { select: { id: true, title: true } },
      },
    })

    const wsPayload = {
      type: 'mention',
      data: {
        id: mention.id,
        context: mention.context,
        mentioner: mention.mentioner,
        group: mention.group,
        note: mention.note,
        messageId: mention.messageId,
        read: false,
        createdAt: mention.createdAt.toISOString(),
      },
    }
    sendToUser(user.id, wsPayload)

    const mentionerLabel = mentioner?.displayName || mentioner?.username || 'Кто-то'
    let pushBody: string
    if (context === 'note' && mention.note) {
      pushBody = `${mentionerLabel} упомянул вас в «${mention.note.title}»`
    } else if (context === 'group_message' && mention.group) {
      pushBody = `${mentionerLabel} упомянул вас в «${mention.group.title}»`
    } else {
      pushBody = `${mentionerLabel} упомянул вас в личном сообщении`
    }

    sendPush(app, user.id, {
      title: 'Вас упомянули',
      body: pushBody,
      data: {
        type: 'mention',
        mentionId: mention.id,
        context: mention.context,
        ...(mention.group ? { groupId: mention.group.id } : {}),
        ...(mention.note ? { noteId: mention.note.id } : {}),
        ...(mention.messageId ? { messageId: mention.messageId } : {}),
      },
    }).catch((e: unknown) => console.error('[mention] push failed:', e))
  }
}

export async function getMentions(app: FastifyInstance, userId: string) {
  return app.prisma.mention.findMany({
    where: { mentionedUserId: userId },
    include: {
      mentioner: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      group: { select: { id: true, title: true } },
      note: { select: { id: true, title: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: 100,
  })
}

export async function markMentionsRead(app: FastifyInstance, userId: string) {
  await app.prisma.mention.updateMany({
    where: { mentionedUserId: userId, read: false },
    data: { read: true },
  })
}
