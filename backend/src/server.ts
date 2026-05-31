import { buildApp } from './app.js'
import { env } from './config/env.js'

async function start() {
  const app = await buildApp()

  const signals: NodeJS.Signals[] = ['SIGTERM', 'SIGINT']
  signals.forEach((signal) =>
    process.on(signal, () => {
      app.close().then(() => process.exit(0)).catch(() => process.exit(1))
    }),
  )

  process.on('unhandledRejection', (err) => {
    console.error('[unhandledRejection]', err)
  })

  try {
    await app.listen({ port: env.PORT, host: '0.0.0.0' })
    console.log(`✅ Server running on port ${env.PORT}`)
  } catch (err) {
    app.log.error(err)
    process.exit(1)
  }
}

start()
