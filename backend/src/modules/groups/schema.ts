import { z } from 'zod'

export const createGroupSchema = z.object({
  title: z.string().min(1, 'Название обязательно').max(100),
})

export const updateGroupSchema = z.object({
  title: z.string().trim().min(1, 'Название обязательно').max(100),
})

export type CreateGroupDto = z.infer<typeof createGroupSchema>
export type UpdateGroupDto = z.infer<typeof updateGroupSchema>
