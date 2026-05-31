import { FastifyInstance } from 'fastify'
import {
  CreateNoteDto,
  UpdateNoteDto,
  NotesQueryDto,
  MoveNoteDto,
  CreateChecklistItemDto,
  UpdateChecklistItemDto,
} from './schema.js'
import { errors } from '../../utils/errors.js'
import { requireGroupMember } from '../../middleware/auth.js'
import {
  notifyNewNote,
  notifyNoteUpdated,
  notifyChecklistCompleted,
} from '../notifications/service.js'

async function ensurePersonalGroup(app: FastifyInstance, userId: string) {
  const existing = await app.prisma.group.findFirst({
    where: {
      createdBy: userId,
      isPersonal: true,
    },
    select: { id: true },
  })
  if (existing) return existing

  return app.prisma.group.create({
    data: {
      title: 'Личное',
      createdBy: userId,
      isPersonal: true,
      members: {
        create: {
          userId,
          role: 'owner',
        },
      },
    },
    select: { id: true },
  })
}

export async function getNotes(app: FastifyInstance, userId: string, query: NotesQueryDto) {
  const archived = query.archived === 'true' ? true : query.archived === 'false' ? false : undefined
  const personal = query.personal === 'true'

  // Find groups the user belongs to
  let groupIds: string[]
  if (query.groupId) {
    const isMember = await requireGroupMember(app, userId, query.groupId)
    if (!isMember) throw errors.forbidden()
    groupIds = [query.groupId]
  } else if (personal) {
    const personalGroup = await ensurePersonalGroup(app, userId)
    groupIds = [personalGroup.id]
  } else {
    const memberships = await app.prisma.groupMember.findMany({
      where: { userId },
      select: { groupId: true },
    })
    groupIds = memberships.map((m) => m.groupId)
  }

  return app.prisma.note.findMany({
    where: {
      groupId: { in: groupIds },
      deletedAt: null,
      ...(archived !== undefined && { archived }),
      ...(query.search && {
        OR: [
          { title: { contains: query.search, mode: 'insensitive' } },
          { content: { contains: query.search, mode: 'insensitive' } },
        ],
      }),
    },
    include: {
      creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      checklistItems: { orderBy: { position: 'asc' } },
      images: true,
      group: { select: { id: true, title: true, isPersonal: true } },
    },
    orderBy: [{ pinned: 'desc' }, { updatedAt: 'desc' }],
  })
}

export async function getNoteById(app: FastifyInstance, noteId: string, userId: string) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    include: {
      creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      checklistItems: { orderBy: { position: 'asc' } },
      images: true,
      group: { select: { id: true, title: true, isPersonal: true } },
    },
  })

  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  return note
}

export async function createNote(app: FastifyInstance, userId: string, dto: CreateNoteDto) {
  const targetGroupId = dto.personal
    ? (await ensurePersonalGroup(app, userId)).id
    : dto.groupId

  if (!targetGroupId) {
    throw errors.badRequest('Не указана группа заметки')
  }

  const targetGroup = await app.prisma.group.findUnique({
    where: { id: targetGroupId },
    select: { id: true, isPersonal: true, createdBy: true, title: true },
  })
  if (!targetGroup) throw errors.notFound('Группа')

  if (targetGroup.isPersonal) {
    if (targetGroup.createdBy !== userId) throw errors.forbidden()
  } else {
    const isMember = await requireGroupMember(app, userId, targetGroupId)
    if (!isMember) throw errors.forbidden()
  }

  const note = await app.prisma.note.create({
    data: {
      groupId: targetGroupId,
      createdBy: userId,
      title: dto.title,
      content: dto.content,
      colorLabel: dto.colorLabel ?? null,
    },
    include: {
      creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      checklistItems: true,
      images: true,
      group: { select: { id: true, title: true, isPersonal: true } },
    },
  })

  // Push всем members группы кроме автора
  if (!note.group.isPersonal) {
    notifyNewNote(app, note, note.group.title).catch((e: unknown) =>
      console.error('[notify] notifyNewNote:', e),
    )
  }

  return note
}

export async function updateNote(app: FastifyInstance, noteId: string, userId: string, dto: UpdateNoteDto) {
  const note = await app.prisma.note.findFirst({ where: { id: noteId, deletedAt: null } })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  const updated = await app.prisma.note.update({
    where: { id: noteId },
    data: dto,
    include: {
      creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      checklistItems: { orderBy: { position: 'asc' } },
      images: true,
      group: { select: { id: true, title: true, isPersonal: true } },
    },
  })

  if (!updated.group.isPersonal) {
    notifyNoteUpdated(
      app,
      {
        noteId: updated.id,
        groupId: updated.groupId,
        updatedBy: userId,
        title: updated.title,
        reason: 'note',
      },
      updated.group.title,
    ).catch((e: unknown) => console.error('[notify] notifyNoteUpdated(note):', e))
  }

  return updated
}

export async function moveNote(app: FastifyInstance, noteId: string, userId: string, dto: MoveNoteDto) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    include: {
      group: { select: { id: true, isPersonal: true, createdBy: true } },
    },
  })
  if (!note) throw errors.notFound('Заметка')

  if (note.group.isPersonal) {
    if (note.group.createdBy !== userId) throw errors.forbidden()
  } else {
    const isMember = await requireGroupMember(app, userId, note.groupId)
    if (!isMember) throw errors.forbidden()
  }

  const targetGroupId = dto.targetPersonal
    ? (await ensurePersonalGroup(app, userId)).id
    : dto.targetGroupId

  if (!targetGroupId) {
    throw errors.badRequest('Не указана целевая группа')
  }

  const targetGroup = await app.prisma.group.findUnique({
    where: { id: targetGroupId },
    select: { id: true, isPersonal: true, createdBy: true },
  })
  if (!targetGroup) throw errors.notFound('Группа')

  if (targetGroup.isPersonal) {
    if (targetGroup.createdBy !== userId) throw errors.forbidden()
  } else {
    const targetMember = await requireGroupMember(app, userId, targetGroupId)
    if (!targetMember) throw errors.forbidden()
  }

  if (targetGroupId === note.groupId) {
    return app.prisma.note.findFirst({
      where: { id: noteId },
      include: {
        creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
        checklistItems: { orderBy: { position: 'asc' } },
        images: true,
        group: { select: { id: true, title: true, isPersonal: true } },
      },
    })
  }

  return app.prisma.note.update({
    where: { id: noteId },
    data: { groupId: targetGroupId },
    include: {
      creator: { select: { id: true, username: true, displayName: true, avatarUrl: true } },
      checklistItems: { orderBy: { position: 'asc' } },
      images: true,
      group: { select: { id: true, title: true, isPersonal: true } },
    },
  })
}

export async function archiveNote(app: FastifyInstance, noteId: string, userId: string) {
  const note = await app.prisma.note.findFirst({ where: { id: noteId, deletedAt: null } })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  await app.prisma.note.update({ where: { id: noteId }, data: { archived: !note.archived } })
  return { archived: !note.archived }
}

export async function deleteNote(app: FastifyInstance, noteId: string, userId: string) {
  const note = await app.prisma.note.findFirst({ where: { id: noteId, deletedAt: null } })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  await app.prisma.note.update({ where: { id: noteId }, data: { deletedAt: new Date() } })
  return { success: true }
}

// Checklist items
export async function addChecklistItem(app: FastifyInstance, noteId: string, userId: string, dto: CreateChecklistItemDto) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    include: { group: { select: { title: true, isPersonal: true } } },
  })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  const maxPosition = await app.prisma.noteChecklistItem.aggregate({
    where: { noteId },
    _max: { position: true },
  })

  const position = dto.position ?? (maxPosition._max.position ?? -1) + 1
  const sectionId = dto.sectionId?.trim() || 'main'

  const item = await app.prisma.noteChecklistItem.create({
    data: { noteId, sectionId, text: dto.text, position },
  })

  return item
}

export async function updateChecklistItem(
  app: FastifyInstance,
  noteId: string,
  itemId: string,
  userId: string,
  dto: UpdateChecklistItemDto
) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    include: {
      group: { select: { title: true, isPersonal: true } },
      checklistItems: { select: { id: true, completed: true } },
    },
  })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  const wasFullyCompleted =
    note.checklistItems.length > 0 &&
    note.checklistItems.every((checklistItem) => checklistItem.completed)

  const item = await app.prisma.noteChecklistItem.update({
    where: { id: itemId },
    data: dto,
  })

  if (!note.group.isPersonal && dto.completed == true && !wasFullyCompleted) {
    const allCompletedNow = note.checklistItems.every((checklistItem) => {
      if (checklistItem.id == itemId) return true
      return checklistItem.completed
    })

    if (allCompletedNow) {
      notifyChecklistCompleted(app, {
        noteId,
        groupId: note.groupId,
        title: note.title,
        updatedBy: userId,
        groupTitle: note.group.title,
      }).catch((e: unknown) =>
        console.error('[notify] notifyChecklistCompleted:', e),
      )
    }
  }

  return item
}

export async function deleteChecklistItem(app: FastifyInstance, noteId: string, itemId: string, userId: string) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    include: { group: { select: { title: true, isPersonal: true } } },
  })
  if (!note) throw errors.notFound('Заметка')

  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()

  await app.prisma.noteChecklistItem.delete({ where: { id: itemId } })

  return { success: true }
}
