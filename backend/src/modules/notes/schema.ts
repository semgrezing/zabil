import { z } from 'zod'

export const createNoteSchema = z.object({
  groupId: z.string().uuid().optional(),
  personal: z.boolean().optional(),
  title: z.string().min(1, 'Заголовок обязателен').max(255),
  content: z.string().default(''),
  colorLabel: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'Некорректный цвет')
    .optional()
    .nullable(),
  pinned: z.boolean().optional(),
})

export const updateNoteSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  content: z.string().optional(),
  colorLabel: z
    .string()
    .regex(/^#[0-9a-fA-F]{6}$/, 'Некорректный цвет')
    .optional()
    .nullable(),
  pinned: z.boolean().optional(),
})

export const notesQuerySchema = z.object({
  groupId: z.string().uuid().optional(),
  search: z.string().optional(),
  archived: z.enum(['true', 'false']).optional(),
  personal: z.enum(['true', 'false']).optional(),
  limit: z.string().optional().transform((v) => (v ? Math.min(parseInt(v, 10), 200) : 50)),
  cursor: z.string().optional(), // ISO date cursor for pagination
})

export const moveNoteSchema = z
  .object({
    targetGroupId: z.string().uuid().optional(),
    targetPersonal: z.boolean().optional(),
  })
  .refine(
    (v) => Boolean(v.targetGroupId) || v.targetPersonal === true,
    'Укажите targetGroupId или targetPersonal=true',
  )

export const createChecklistItemSchema = z.object({
  text: z.string().min(1).max(500),
  position: z.number().int().min(0).optional(),
  sectionId: z.string().trim().min(1).max(64).optional(),
})

export const updateChecklistItemSchema = z.object({
  text: z.string().min(1).max(500).optional(),
  completed: z.boolean().optional(),
  position: z.number().int().min(0).optional(),
})

export type CreateNoteDto = z.infer<typeof createNoteSchema>
export type UpdateNoteDto = z.infer<typeof updateNoteSchema>
export type NotesQueryDto = z.infer<typeof notesQuerySchema>
export type MoveNoteDto = z.infer<typeof moveNoteSchema>
export type CreateChecklistItemDto = z.infer<typeof createChecklistItemSchema>
export type UpdateChecklistItemDto = z.infer<typeof updateChecklistItemSchema>
