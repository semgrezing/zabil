import { FastifyInstance } from 'fastify'
import { authenticate } from '../../middleware/auth.js'
import { checkForUpdate, createRelease } from './service.js'
import { AppError } from '../../utils/errors.js'

export async function updateRoutes(app: FastifyInstance) {
  // GET /update?platform=android|windows&currentVersion=1.4.1
  // No auth — клиент проверяет до login
  app.get('/', async (request, reply) => {
    const q = request.query as { platform?: string; currentVersion?: string }
    const platform = q.platform
    const currentVersion = q.currentVersion ?? '0.0.0'

    if (platform !== 'android' && platform !== 'windows') {
      return reply.status(400).send({
        error: 'platform должен быть android или windows',
        code: 'VALIDATION_ERROR',
      })
    }

    try {
      const result = await checkForUpdate(app, platform, currentVersion)
      return reply.send(result)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })

  // POST /update/releases — admin only (создаёт запись о новом релизе)
  app.post('/releases', { preHandler: [authenticate] }, async (request, reply) => {
    const body = request.body as {
      version?: string
      platform?: string
      downloadUrl?: string
      sha256?: string
      fileSize?: number
      mandatory?: boolean
      minSupportedVersion?: string
      notes?: string
    }
    if (!body?.version || !body?.platform || !body?.downloadUrl) {
      return reply.status(400).send({
        error: 'version, platform, downloadUrl обязательны',
        code: 'VALIDATION_ERROR',
      })
    }
    try {
      const release = await createRelease(app, request.user.userId, {
        version: body.version,
        platform: body.platform,
        downloadUrl: body.downloadUrl,
        sha256: body.sha256,
        fileSize: body.fileSize,
        mandatory: body.mandatory,
        minSupportedVersion: body.minSupportedVersion,
        notes: body.notes,
      })
      return reply.status(201).send(release)
    } catch (err) {
      if (err instanceof AppError) {
        return reply.status(err.statusCode).send({ error: err.message, code: err.code })
      }
      throw err
    }
  })
}
