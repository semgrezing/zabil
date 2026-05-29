import { z } from 'zod'

export const sendInvitationSchema = z.object({
  groupId: z.string().uuid(),
  username: z.string().min(1),
})

export type SendInvitationDto = z.infer<typeof sendInvitationSchema>
