import { FastifyInstance } from 'fastify'
import { errors } from '../../utils/errors.js'
import { env } from '../../config/env.js'
import { sendToUser } from '../chats/wsHub.js'

/**
 * Push-уведомления (Stage 7).
 *
 * Текущая реализация: device tokens сохраняются в БД, но реальная отправка
 * через FCM зависит от валидного `FIREBASE_SERVICE_ACCOUNT_JSON`. Если ключ
 * не задан — `sendPush` логирует payload и no-op (без throw, без падения вызывающего
 * кода). Это позволяет приложению работать без Firebase setup; включить push
 * можно одним env var-ом без изменения кода.
 *
 * При реальном включении: `npm i firebase-admin` и раскомментировать импорт +
 * инициализацию.
 */

let _adminApp: any | null = null
let _initAttempted = false
const _checklistCompletionCooldown = new Map<string, number>()
const CHECKLIST_COMPLETION_COOLDOWN_MS = 5 * 60 * 1000

/* eslint-disable @typescript-eslint/no-var-requires */
async function ensureFirebase() {
  if (_initAttempted) return _adminApp
  _initAttempted = true
  const raw = env.FIREBASE_SERVICE_ACCOUNT_JSON.trim()
  if (!raw) {
    console.warn('[push] FIREBASE_SERVICE_ACCOUNT_JSON пуст — push в no-op режиме')
    return null
  }
  try {
    const credentials = JSON.parse(raw)
    // Динамический import чтобы не требовать пакет если push не используется
    const admin = await import('firebase-admin')
    _adminApp = admin.default.initializeApp({
      credential: admin.default.credential.cert(credentials),
    })
    console.info('[push] Firebase Admin SDK инициализирован')
    return _adminApp
  } catch (err) {
    console.error('[push] Не удалось инициализировать Firebase:', err)
    return null
  }
}

type PushPayload = {
  title: string
  body: string
  data?: Record<string, string>
}

/**
 * Регистрация device token. Upsert по `[userId, token]`.
 */
export async function registerDevice(
  app: FastifyInstance,
  userId: string,
  platform: string,
  token: string,
) {
  if (!['android', 'windows', 'ios'].includes(platform)) {
    throw errors.badRequest('Неподдерживаемая платформа')
  }
  if (!token || token.length < 8) {
    throw errors.badRequest('Невалидный токен устройства')
  }
  const existing = await app.prisma.deviceToken.findUnique({
    where: { userId_token: { userId, token } },
  })
  if (existing) {
    return existing
  }
  return app.prisma.deviceToken.create({
    data: { userId, platform, token },
  })
}

export async function unregisterDevice(app: FastifyInstance, userId: string, tokenId: string) {
  const dt = await app.prisma.deviceToken.findUnique({ where: { id: tokenId } })
  if (!dt) throw errors.notFound('Токен')
  if (dt.userId !== userId) throw errors.forbidden()
  await app.prisma.deviceToken.delete({ where: { id: tokenId } })
}

/**
 * Низкоуровневая отправка push в массив токенов. Учитывает платформу.
 * Возвращает количество успешных отправок.
 */
export async function sendPush(
  app: FastifyInstance,
  userId: string,
  payload: PushPayload,
): Promise<number> {
  const tokens = await app.prisma.deviceToken.findMany({ where: { userId } })
  if (tokens.length === 0) return 0

  const adminApp = await ensureFirebase()
  if (!adminApp) {
    console.log(`[push:noop] → user=${userId} title=${payload.title} body=${payload.body}`)
    return 0
  }

  // Группируем по платформам (для будущей APNs/WNS логики)
  const android = tokens.filter((t) => t.platform === 'android').map((t) => t.token)
  let success = 0

  if (android.length > 0) {
    try {
      const admin = await import('firebase-admin')
      const res = await admin.default.messaging().sendEachForMulticast({
        tokens: android,
        notification: { title: payload.title, body: payload.body },
        data: payload.data ?? {},
      })
      success += res.successCount
      // Удаляем недействительные токены
      res.responses.forEach((r, i) => {
        if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
          app.prisma.deviceToken
            .delete({ where: { userId_token: { userId, token: android[i] } } })
            .catch(() => {})
        }
      })
    } catch (err) {
      console.error('[push] FCM send failed:', err)
    }
  }

  // Windows и прочие не-FCM платформы: доставка через WebSocket.
  // Если пользователь online — получит notification event → local notification на клиенте.
  sendToUser(userId, {
    type: 'notification',
    data: {
      title: payload.title,
      body: payload.body,
      ...payload.data,
    },
  })

  return success
}

// ─── Высокоуровневые хелперы по событиям ────────────────────────────────────

export async function notifyNewInvitation(
  app: FastifyInstance,
  invitation: { id: string; receiverId: string; group: { title: string }; sender: { username: string } },
) {
  await sendPush(app, invitation.receiverId, {
    title: 'Новое приглашение',
    body: `${invitation.sender.username} пригласил вас в «${invitation.group.title}»`,
    data: { type: 'invitation', invitationId: invitation.id },
  })
}

export async function notifyInvitationAccepted(
  app: FastifyInstance,
  invitation: { id: string; senderId: string; group: { title: string }; receiver: { username: string } },
) {
  await sendPush(app, invitation.senderId, {
    title: 'Приглашение принято',
    body: `${invitation.receiver.username} вступил в «${invitation.group.title}»`,
    data: { type: 'invitation_accepted', invitationId: invitation.id },
  })
}

export async function notifyInvitationDeclined(
  app: FastifyInstance,
  invitation: { id: string; senderId: string; group: { title: string }; receiver: { username: string } },
) {
  await sendPush(app, invitation.senderId, {
    title: 'Приглашение отклонено',
    body: `${invitation.receiver.username} отклонил приглашение в «${invitation.group.title}»`,
    data: { type: 'invitation_declined', invitationId: invitation.id },
  })
}

export async function notifyGroupMemberRemoved(
  app: FastifyInstance,
  payload: {
    userId: string
    groupId: string
    groupTitle: string
    actorName: string
  },
) {
  await sendPush(app, payload.userId, {
    title: 'Доступ к группе изменен',
    body: `Вы исключены из «${payload.groupTitle}» (${payload.actorName})`,
    data: {
      type: 'group_member_removed',
      groupId: payload.groupId,
    },
  })
}

export async function notifyGroupDeleted(
  app: FastifyInstance,
  payload: {
    userId: string
    groupId: string
    groupTitle: string
    actorName: string
  },
) {
  await sendPush(app, payload.userId, {
    title: 'Группа удалена',
    body: `Группа «${payload.groupTitle}» удалена (${payload.actorName})`,
    data: {
      type: 'group_deleted',
      groupId: payload.groupId,
    },
  })
}

export async function notifyNewNote(
  app: FastifyInstance,
  note: { id: string; groupId: string; createdBy: string; title: string },
  groupTitle: string,
) {
  const members = await app.prisma.groupMember.findMany({
    where: {
      groupId: note.groupId,
      userId: { not: note.createdBy },
      user: { notePushEnabled: true },
    },
    select: { userId: true },
  })
  await Promise.all(
    members.map((m) =>
      sendPush(app, m.userId, {
        title: groupTitle,
        body: `Новая заметка: «${note.title}»`,
        data: { type: 'new_note', noteId: note.id, groupId: note.groupId },
      }),
    ),
  )
}

export async function notifyNoteUpdated(
  app: FastifyInstance,
  payload: {
    noteId: string
    groupId: string
    updatedBy: string
    title: string
    reason: 'note' | 'checklist'
  },
  groupTitle: string,
) {
  const members = await app.prisma.groupMember.findMany({
    where: {
      groupId: payload.groupId,
      userId: { not: payload.updatedBy },
      user: { notePushEnabled: true },
    },
    select: { userId: true },
  })

  const body = `Изменена заметка: «${payload.title}»`

  await Promise.all(
    members.map((m) =>
      sendPush(app, m.userId, {
        title: groupTitle,
        body,
        data: {
          type: 'note_updated',
          noteId: payload.noteId,
          groupId: payload.groupId,
        },
      }),
    ),
  )
}

export async function notifyNewGroupMessage(
  app: FastifyInstance,
  message: { id: string; groupId: string; senderId: string; body: string; noteId?: string | null },
  senderUsername: string,
  groupTitle: string,
  isOnline: (userId: string) => boolean,
) {
  const members = await app.prisma.groupMember.findMany({
    where: { groupId: message.groupId, userId: { not: message.senderId } },
    select: { userId: true },
  })
  // Push только тем, кто не online (online получит через WebSocket)
  await Promise.all(
    members
      .filter((m) => !isOnline(m.userId))
      .map((m) =>
        sendPush(app, m.userId, {
          title: groupTitle,
          body: `${senderUsername}: ${message.body.slice(0, 120)}`,
          data: {
            type: 'group_message',
            messageId: message.id,
            groupId: message.groupId,
            ...(message.noteId ? { noteId: message.noteId } : {}),
          },
        }),
      ),
  )
}

export async function notifyNewPersonalMessage(
  app: FastifyInstance,
  message: { id: string; senderId: string; receiverId: string; body: string },
  senderUsername: string,
  isOnline: (userId: string) => boolean,
) {
  if (isOnline(message.receiverId)) return
  await sendPush(app, message.receiverId, {
    title: senderUsername,
    body: message.body.slice(0, 120),
    data: { type: 'personal_message', messageId: message.id, senderId: message.senderId },
  })
}

export async function notifyChecklistCompleted(
  app: FastifyInstance,
  payload: {
    noteId: string
    groupId: string
    title: string
    updatedBy: string
    groupTitle: string
  },
) {
  const cooldownKey = `${payload.groupId}:${payload.noteId}`
  const now = Date.now()
  const lastSentAt = _checklistCompletionCooldown.get(cooldownKey) ?? 0
  if (now - lastSentAt < CHECKLIST_COMPLETION_COOLDOWN_MS) {
    return
  }

  const members = await app.prisma.groupMember.findMany({
    where: {
      groupId: payload.groupId,
      userId: { not: payload.updatedBy },
      user: { checklistPushEnabled: true },
    },
    select: { userId: true },
  })
  if (members.length === 0) return

  _checklistCompletionCooldown.set(cooldownKey, now)

  await Promise.all(
    members.map((m) =>
      sendPush(app, m.userId, {
        title: payload.groupTitle,
        body: `Чеклист завершен: «${payload.title}»`,
        data: {
          type: 'checklist_completed',
          noteId: payload.noteId,
          groupId: payload.groupId,
        },
      }),
    ),
  )
}

export async function notifyAppRelease(
  app: FastifyInstance,
  payload: {
    version: string
    platform: string
    downloadUrl: string
    notes?: string | null
    mandatory?: boolean
  },
) {
  const users = await app.prisma.user.findMany({
    where: { releasePushEnabled: true },
    select: { id: true },
  })

  await Promise.all(
    users.map((user) =>
      sendPush(app, user.id, {
        title: `Доступна версия ${payload.version}`,
        body: payload.notes?.trim().length != null && payload.notes!.trim().length > 0
            ? payload.notes!.trim()
            : 'Доступно новое обновление приложения',
        data: {
          type: 'app_release',
          version: payload.version,
          platform: payload.platform,
          downloadUrl: payload.downloadUrl,
          mandatory: payload.mandatory == true ? 'true' : 'false',
        },
      }),
    ),
  )
}
