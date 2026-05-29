import { z } from 'zod'

export const registerSchema = z.object({
  username: z
    .string()
    .min(3, 'Имя пользователя минимум 3 символа')
    .max(30, 'Имя пользователя максимум 30 символов')
    .regex(/^[a-zA-Z0-9_]+$/, 'Допустимы только буквы, цифры и _'),
  password: z.string().min(8, 'Пароль минимум 8 символов').max(100),
})

export const loginSchema = z.object({
  username: z.string().min(1),
  password: z.string().min(1),
})

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
})

export type RegisterDto = z.infer<typeof registerSchema>
export type LoginDto = z.infer<typeof loginSchema>
export type RefreshDto = z.infer<typeof refreshSchema>
