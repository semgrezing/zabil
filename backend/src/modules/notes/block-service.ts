import { FastifyInstance } from 'fastify'
import { CreateBlockDto, UpdateBlockDto, ReorderBlocksDto } from './block-schema.js'
import { errors } from '../../utils/errors.js'
import { requireGroupMember } from '../../middleware/auth.js'

async function validateNoteAccess(app: FastifyInstance, noteId: string, userId: string) {
  const note = await app.prisma.note.findFirst({
    where: { id: noteId, deletedAt: null },
    select: { id: true, groupId: true },
  })
  if (!note) throw errors.notFound('Заметка')
  const isMember = await requireGroupMember(app, userId, note.groupId)
  if (!isMember) throw errors.forbidden()
  return note
}

export async function createBlock(
  app: FastifyInstance,
  noteId: string,
  userId: string,
  dto: CreateBlockDto,
) {
  await validateNoteAccess(app, noteId, userId)

  await app.prisma.noteBlock.updateMany({
    where: { noteId, position: { gte: dto.position } },
    data: { position: { increment: 1 } },
  })

  const block = await app.prisma.noteBlock.create({
    data: {
      noteId,
      type: dto.type,
      content: dto.content,
      position: dto.position,
    },
  })

  await app.prisma.note.update({
    where: { id: noteId },
    data: { updatedAt: new Date() },
  })

  return block
}

export async function updateBlock(
  app: FastifyInstance,
  noteId: string,
  blockId: string,
  userId: string,
  dto: UpdateBlockDto,
) {
  await validateNoteAccess(app, noteId, userId)

  const block = await app.prisma.noteBlock.update({
    where: { id: blockId, noteId },
    data: { content: dto.content },
  })

  await app.prisma.note.update({
    where: { id: noteId },
    data: { updatedAt: new Date() },
  })

  return block
}

export async function deleteBlock(
  app: FastifyInstance,
  noteId: string,
  blockId: string,
  userId: string,
) {
  await validateNoteAccess(app, noteId, userId)

  const block = await app.prisma.noteBlock.findUnique({
    where: { id: blockId, noteId },
    select: { position: true },
  })
  if (!block) throw errors.notFound('Блок')

  await app.prisma.$transaction([
    app.prisma.noteBlock.delete({ where: { id: blockId } }),
    app.prisma.noteBlock.updateMany({
      where: { noteId, position: { gt: block.position } },
      data: { position: { decrement: 1 } },
    }),
  ])

  await app.prisma.note.update({
    where: { id: noteId },
    data: { updatedAt: new Date() },
  })

  return { success: true }
}

export async function reorderBlocks(
  app: FastifyInstance,
  noteId: string,
  userId: string,
  dto: ReorderBlocksDto,
) {
  await validateNoteAccess(app, noteId, userId)

  await app.prisma.$transaction(
    dto.orderedIds.map((id, index) =>
      app.prisma.noteBlock.update({
        where: { id, noteId },
        data: { position: index },
      }),
    ),
  )

  await app.prisma.note.update({
    where: { id: noteId },
    data: { updatedAt: new Date() },
  })

  return { success: true }
}

export async function ensureBlocksMigrated(app: FastifyInstance, noteId: string) {
  const note = await app.prisma.note.findUnique({
    where: { id: noteId },
    include: {
      checklistItems: { orderBy: { position: 'asc' } },
      images: true,
    },
  })
  if (!note || note.migrated) return

  const blocks: { type: string; content: string; position: number }[] = []
  let pos = 0

  if (note.content && note.content !== '' && note.content !== '[{"insert":"\\n"}]') {
    blocks.push({
      type: 'text',
      content: JSON.stringify({ delta: JSON.parse(note.content) }),
      position: pos++,
    })
  }

  const sections = new Map<string, typeof note.checklistItems>()
  for (const item of note.checklistItems) {
    const sid = item.sectionId || 'main'
    if (!sections.has(sid)) sections.set(sid, [])
    sections.get(sid)!.push(item)
  }
  for (const [, items] of sections) {
    blocks.push({
      type: 'checklist',
      content: JSON.stringify({
        items: items.map((i) => ({ id: i.id, text: i.text, completed: i.completed })),
      }),
      position: pos++,
    })
  }

  for (const img of note.images) {
    blocks.push({
      type: 'image',
      content: JSON.stringify({
        imageId: img.id,
        filename: img.filename,
        path: img.path,
        originalName: img.originalName,
        mimeType: img.mimeType,
        fileSize: img.fileSize,
      }),
      position: pos++,
    })
  }

  if (blocks.length === 0) {
    blocks.push({
      type: 'text',
      content: JSON.stringify({ delta: [{ insert: '\n' }] }),
      position: 0,
    })
  }

  await app.prisma.$transaction([
    ...blocks.map((b) =>
      app.prisma.noteBlock.create({ data: { noteId, ...b } }),
    ),
    app.prisma.note.update({ where: { id: noteId }, data: { migrated: true } }),
  ])
}
