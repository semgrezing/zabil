import { z } from 'zod'

export const updateProfileSchema = z.object({
  displayName: z.string().trim().max(50).optional().nullable(),
})

export type UpdateProfileDto = z.infer<typeof updateProfileSchema>
