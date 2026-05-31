import { z } from 'zod'

export const updateProfileSchema = z.object({
  username: z
    .string()
    .trim()
    .min(3, 'Имя пользователя минимум 3 символа')
    .max(30, 'Имя пользователя максимум 30 символов')
    .regex(/^[a-zA-Z0-9_]+$/, 'Допустимы только буквы, цифры и _')
    .optional(),
  displayName: z.string().trim().max(50).optional().nullable(),
  notePushEnabled: z.boolean().optional(),
  checklistPushEnabled: z.boolean().optional(),
  releasePushEnabled: z.boolean().optional(),
})

export type UpdateProfileDto = z.infer<typeof updateProfileSchema>
