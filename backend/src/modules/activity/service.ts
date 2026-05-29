import { FastifyInstance } from 'fastify'

export interface ActivityItem {
  id: string
  type: 'note_created' | 'note_updated' | 'message_sent' | 'member_joined'
  actorId: string
  actorName: string
  actorAvatar: string | null
  groupId: string
  groupTitle: string
  targetId: string
  targetTitle: string | null
  createdAt: Date
}

export async function getActivityFeed(
  app: FastifyInstance,
  userId: string,
  limit = 50,
): Promise<ActivityItem[]> {
  const memberships = await app.prisma.groupMember.findMany({
    where: { userId },
    select: { groupId: true },
  })
  const groupIds = memberships.map((m) => m.groupId)
  if (groupIds.length === 0) return []

  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)

  const [notes, messages, members] = await Promise.all([
    app.prisma.note.findMany({
      where: {
        groupId: { in: groupIds },
        deletedAt: null,
        OR: [{ createdAt: { gte: cutoff } }, { updatedAt: { gte: cutoff } }],
      },
      include: {
        creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        group: { select: { id: true, title: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: limit,
    }),

    app.prisma.groupChatMessage.findMany({
      where: {
        groupId: { in: groupIds },
        createdAt: { gte: cutoff },
      },
      include: {
        sender: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        group: { select: { id: true, title: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    }),

    app.prisma.groupMember.findMany({
      where: {
        groupId: { in: groupIds },
        joinedAt: { gte: cutoff },
      },
      include: {
        user: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        group: { select: { id: true, title: true } },
      },
      orderBy: { joinedAt: 'desc' },
      take: 20,
    }),
  ])

  const items: ActivityItem[] = []

  for (const note of notes) {
    const isNew = note.createdAt >= cutoff && Math.abs(note.createdAt.getTime() - note.updatedAt.getTime()) < 5000
    items.push({
      id: `note_${note.id}_${isNew ? 'created' : 'updated'}`,
      type: isNew ? 'note_created' : 'note_updated',
      actorId: note.creator.id,
      actorName: note.creator.displayName ?? note.creator.username,
      actorAvatar: note.creator.avatarUrl ?? null,
      groupId: note.groupId,
      groupTitle: note.group.title,
      targetId: note.id,
      targetTitle: note.title,
      createdAt: isNew ? note.createdAt : note.updatedAt,
    })
  }

  for (const msg of messages) {
    const body = msg.body ?? ''
    items.push({
      id: `msg_${msg.id}`,
      type: 'message_sent',
      actorId: msg.sender.id,
      actorName: msg.sender.displayName ?? msg.sender.username,
      actorAvatar: msg.sender.avatarUrl ?? null,
      groupId: msg.groupId,
      groupTitle: msg.group.title,
      targetId: msg.id,
      targetTitle: body.length > 60 ? `${body.slice(0, 60)}…` : (body || null),
      createdAt: msg.createdAt,
    })
  }

  for (const member of members) {
    items.push({
      id: `member_${member.groupId}_${member.userId}`,
      type: 'member_joined',
      actorId: member.user.id,
      actorName: member.user.displayName ?? member.user.username,
      actorAvatar: member.user.avatarUrl ?? null,
      groupId: member.groupId,
      groupTitle: member.group.title,
      targetId: member.groupId,
      targetTitle: member.group.title,
      createdAt: member.joinedAt,
    })
  }

  const seen = new Set<string>()
  return items
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
    .filter((item) => {
      if (seen.has(item.id)) return false
      seen.add(item.id)
      return true
    })
    .slice(0, limit)
}
