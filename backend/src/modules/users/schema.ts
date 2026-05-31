import { z } from 'zod'

export const updateProfileSchema = z.object({
  displayName: z.string().trim().max(50).optional().nullable(),
  notePushEnabled: z.boolean().optional(),
  checklistPushEnabled: z.boolean().optional(),
  releasePushEnabled: z.boolean().optional(),
})

export type UpdateProfileDto = z.infer<typeof updateProfileSchema>
