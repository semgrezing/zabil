import { z } from 'zod'
import 'dotenv/config'

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('3000').transform(Number),
  DATABASE_URL: z.string().min(1),
  JWT_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_DAYS: z.string().default('30').transform(Number),
  CORS_ORIGIN: z.string().default('*'),
  UPLOADS_PATH: z.string().default('./uploads'),
  RELEASES_PATH: z.string().default('./releases'),
  MAX_UPLOAD_SIZE: z.string().default('52428800').transform(Number),
  APP_VERSION: z.string().default('1.0.0'),
  // Firebase service-account JSON (raw string). Если пустой/невалидный —
  // push-уведомления no-op (логируются, не отправляются).
  FIREBASE_SERVICE_ACCOUNT_JSON: z.string().default(''),
  // Origin для построения downloadUrl в /update. Например https://api.achiemvemer.ru
  PUBLIC_ORIGIN: z.string().default('https://api.achiemvemer.ru'),
})

const parsed = envSchema.safeParse(process.env)

if (!parsed.success) {
  console.error('❌ Invalid environment variables:')
  console.error(parsed.error.flatten().fieldErrors)
  process.exit(1)
}

export const env = parsed.data
