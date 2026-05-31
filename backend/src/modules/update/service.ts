import { FastifyInstance } from 'fastify'
import { errors } from '../../utils/errors.js'
import { env } from '../../config/env.js'
import { notifyAppRelease } from '../notifications/service.js'

type Platform = 'android' | 'windows'

/**
 * Сравнение semver-строк (только x.y.z, без pre-release / build metadata).
 * Возвращает 1 если a > b, -1 если a < b, 0 если равны.
 */
export function compareSemver(a: string, b: string): number {
  const pa = a.split('.').map((s) => parseInt(s, 10) || 0)
  const pb = b.split('.').map((s) => parseInt(s, 10) || 0)
  for (let i = 0; i < 3; i++) {
    const x = pa[i] ?? 0
    const y = pb[i] ?? 0
    if (x > y) return 1
    if (x < y) return -1
  }
  return 0
}

/**
 * Проверка обновления для платформы.
 * Возвращает данные последнего релиза + флаги hasUpdate / mandatory.
 */
export async function checkForUpdate(
  app: FastifyInstance,
  platform: Platform,
  currentVersion: string,
) {
  const latest = await app.prisma.appRelease.findFirst({
    where: { platform },
    orderBy: { releasedAt: 'desc' },
  })

  if (!latest) {
    // Нет релизов — ничего не предлагаем
    return {
      hasUpdate: false,
      latestVersion: currentVersion,
      downloadUrl: null,
      sha256: null,
      fileSize: null,
      mandatory: false,
      notes: null,
    }
  }

  const cmp = compareSemver(latest.version, currentVersion)
  const hasUpdate = cmp > 0

  // mandatory если у релиза флаг ИЛИ текущая версия ниже minSupported
  let mandatory = latest.mandatory
  if (latest.minSupportedVersion && compareSemver(currentVersion, latest.minSupportedVersion) < 0) {
    mandatory = true
  }

  // downloadUrl в БД хранится относительный (`/releases/...`), отдаём абсолютный
  const downloadUrl = latest.downloadUrl.startsWith('http')
    ? latest.downloadUrl
    : `${env.PUBLIC_ORIGIN}${latest.downloadUrl}`

  return {
    hasUpdate,
    latestVersion: latest.version,
    downloadUrl: hasUpdate ? downloadUrl : null,
    sha256: hasUpdate ? latest.sha256 : null,
    fileSize: hasUpdate ? latest.fileSize : null,
    mandatory: hasUpdate ? mandatory : false,
    notes: hasUpdate ? latest.notes : null,
  }
}

/**
 * Создание новой записи релиза (для ops-скрипта заливки).
 * Доступ — только для admin (пока проверяем по username 'semva').
 */
export async function createRelease(
  app: FastifyInstance,
  userId: string,
  dto: {
    version: string
    platform: string
    downloadUrl: string
    sha256?: string
    fileSize?: number
    mandatory?: boolean
    minSupportedVersion?: string
    notes?: string
  },
) {
  const user = await app.prisma.user.findUnique({ where: { id: userId } })
  if (!user || !user.isAdmin) {
    throw errors.forbidden()
  }
  if (!['android', 'windows'].includes(dto.platform)) {
    throw errors.badRequest('Платформа должна быть android или windows')
  }
  if (!/^\d+\.\d+\.\d+$/.test(dto.version)) {
    throw errors.badRequest('Версия должна быть в формате x.y.z')
  }
  // Upsert чтобы можно было пересоздать релиз той же версии (при rebuild)
  const release = await app.prisma.appRelease.upsert({
    where: { platform_version: { platform: dto.platform, version: dto.version } },
    create: {
      version: dto.version,
      platform: dto.platform,
      downloadUrl: dto.downloadUrl,
      sha256: dto.sha256,
      fileSize: dto.fileSize,
      mandatory: dto.mandatory ?? false,
      minSupportedVersion: dto.minSupportedVersion,
      notes: dto.notes,
    },
    update: {
      downloadUrl: dto.downloadUrl,
      sha256: dto.sha256,
      fileSize: dto.fileSize,
      mandatory: dto.mandatory ?? false,
      minSupportedVersion: dto.minSupportedVersion,
      notes: dto.notes,
    },
  })

  const downloadUrl = release.downloadUrl.startsWith('http')
    ? release.downloadUrl
    : `${env.PUBLIC_ORIGIN}${release.downloadUrl}`

  notifyAppRelease(app, {
    version: release.version,
    platform: release.platform,
    downloadUrl,
    notes: release.notes,
    mandatory: release.mandatory,
  }).catch((e: unknown) => console.error('[notify] notifyAppRelease:', e))

  return release
}
