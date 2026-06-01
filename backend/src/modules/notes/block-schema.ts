import { z } from 'zod'

export const createBlockSchema = z.object({
  type: z.enum(['text', 'checklist', 'image', 'divider']),
  content: z.string().default('{}'),
  position: z.number().int().min(0),
})

export const updateBlockSchema = z.object({
  content: z.string().optional(),
})

export const reorderBlocksSchema = z.object({
  orderedIds: z.array(z.string().uuid()).min(1),
})

export type CreateBlockDto = z.infer<typeof createBlockSchema>
export type UpdateBlockDto = z.infer<typeof updateBlockSchema>
export type ReorderBlocksDto = z.infer<typeof reorderBlocksSchema>
