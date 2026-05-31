import { FastifyInstance } from 'fastify'
import { SendInvitationDto } from './schema.js'
import { errors } from '../../utils/errors.js'
import {
  notifyNewInvitation,
  notifyInvitationAccepted,
  notifyInvitationDeclined,
} from '../notifications/service.js'

type InvitationActionResult = {
  success: true
  status: string
  alreadyProcessed: boolean
}

export async function sendInvitation(app: FastifyInstance, senderId: string, dto: SendInvitationDto) {
  // Check sender is a member of the group
  const senderMember = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: dto.groupId, userId: senderId } },
  })
  if (!senderMember) throw errors.forbidden()

  const group = await app.prisma.group.findUnique({
    where: { id: dto.groupId },
    select: { isPersonal: true },
  })
  if (!group) throw errors.notFound('Группа')
  if (group.isPersonal) throw errors.badRequest('В личную группу нельзя приглашать')

  // Find receiver by username
  const receiver = await app.prisma.user.findUnique({
    where: { username: dto.username },
  })
  if (!receiver) throw errors.notFound('Пользователь')

  // Can't invite yourself
  if (receiver.id === senderId) {
    throw errors.badRequest('Пригласить себя не выйдет 😶')
  }

  // Check if already a member
  const alreadyMember = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: dto.groupId, userId: receiver.id } },
  })
  if (alreadyMember) throw errors.conflict('Пользователь уже в группе')

  // Check for existing pending invitation
  const existing = await app.prisma.invitation.findFirst({
    where: {
      groupId: dto.groupId,
      receiverId: receiver.id,
      status: 'pending',
    },
  })
  if (existing) throw errors.conflict('Приглашение уже отправлено')

  const invitation = await app.prisma.invitation.create({
    data: {
      groupId: dto.groupId,
      senderId,
      receiverId: receiver.id,
      status: 'pending',
    },
    include: {
      group: { select: { id: true, title: true } },
      sender: { select: { id: true, username: true } },
      receiver: { select: { id: true, username: true } },
    },
  })

  // Push receiver (fire-and-forget, ошибки не блокируют ответ)
  notifyNewInvitation(app, invitation).catch((e: unknown) =>
    console.error('[notify] notifyNewInvitation:', e),
  )

  return invitation
}

export async function getIncomingInvitations(app: FastifyInstance, userId: string) {
  return app.prisma.invitation.findMany({
    where: { receiverId: userId, status: 'pending' },
    include: {
      group: { select: { id: true, title: true } },
      sender: { select: { id: true, username: true } },
    },
    orderBy: { createdAt: 'desc' },
  })
}

export async function getGroupPendingInvitations(
  app: FastifyInstance,
  userId: string,
  groupId: string,
) {
  const membership = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
    select: { role: true },
  })
  if (!membership) throw errors.forbidden()
  if (membership.role !== 'owner' && membership.role !== 'admin') {
    throw errors.forbidden()
  }

  return app.prisma.invitation.findMany({
    where: { groupId, status: 'pending' },
    include: {
      group: { select: { id: true, title: true } },
      sender: { select: { id: true, username: true, displayName: true } },
      receiver: { select: { id: true, username: true, displayName: true } },
    },
    orderBy: { createdAt: 'desc' },
  })
}

export async function respondToInvitation(
  app: FastifyInstance,
  invitationId: string,
  userId: string,
  action: 'accept' | 'decline'
) {
  const invitation = await app.prisma.invitation.findUnique({
    where: { id: invitationId },
  })

  if (!invitation) throw errors.notFound('Приглашение')
  if (invitation.receiverId !== userId) throw errors.forbidden()

  const targetStatus = action === 'accept' ? 'accepted' : 'declined'

  if (invitation.status !== 'pending') {
    if (invitation.status === 'accepted') {
      // Если приглашение было принято ранее (например, на другом устройстве),
      // гарантируем наличие membership при ретраях.
      await app.prisma.groupMember.upsert({
        where: { groupId_userId: { groupId: invitation.groupId, userId } },
        create: {
          groupId: invitation.groupId,
          userId,
          role: 'member',
        },
        update: {},
      })
    }

    return { success: true, status: invitation.status, alreadyProcessed: true }
  }

  if (action === 'accept') {
    const result: InvitationActionResult = await app.prisma.$transaction(async (tx) => {
      const updated = await tx.invitation.updateMany({
        where: { id: invitationId, status: 'pending' },
        data: { status: 'accepted' },
      })

      if (updated.count === 0) {
        const latest = await tx.invitation.findUnique({
          where: { id: invitationId },
        })
        if (!latest) throw errors.notFound('Приглашение')

        if (latest.status === 'accepted') {
          await tx.groupMember.upsert({
            where: { groupId_userId: { groupId: invitation.groupId, userId } },
            create: {
              groupId: invitation.groupId,
              userId,
              role: 'member',
            },
            update: {},
          })
        }

        return { success: true, status: latest.status, alreadyProcessed: true }
      }

      await tx.groupMember.upsert({
        where: { groupId_userId: { groupId: invitation.groupId, userId } },
        create: {
          groupId: invitation.groupId,
          userId,
          role: 'member',
        },
        update: {},
      })

      return { success: true, status: targetStatus, alreadyProcessed: false }
    })

    if (result.status === 'accepted' && !result.alreadyProcessed) {
      const detailed = await app.prisma.invitation.findUnique({
        where: { id: invitationId },
        include: {
          group: { select: { id: true, title: true } },
          receiver: { select: { id: true, username: true } },
        },
      })
      if (detailed) {
        notifyInvitationAccepted(app, detailed).catch((e: unknown) =>
          console.error('[notify] notifyInvitationAccepted:', e),
        )
      }
    }

    return result
  }

  const result: InvitationActionResult = await app.prisma.$transaction(async (tx) => {
    const updated = await tx.invitation.updateMany({
      where: { id: invitationId, status: 'pending' },
      data: { status: 'declined' },
    })

    if (updated.count === 0) {
      const latest = await tx.invitation.findUnique({
        where: { id: invitationId },
      })
      if (!latest) throw errors.notFound('Приглашение')

      return { success: true, status: latest.status, alreadyProcessed: true }
    }

    return { success: true, status: targetStatus, alreadyProcessed: false }
  })

  if (result.status === 'declined' && !result.alreadyProcessed) {
    const detailed = await app.prisma.invitation.findUnique({
      where: { id: invitationId },
      include: {
        group: { select: { id: true, title: true } },
        receiver: { select: { id: true, username: true } },
      },
    })
    if (detailed) {
      notifyInvitationDeclined(app, detailed).catch((e: unknown) =>
        console.error('[notify] notifyInvitationDeclined:', e),
      )
    }
  }

  return result
}
