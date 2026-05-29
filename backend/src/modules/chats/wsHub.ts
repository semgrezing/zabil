/**
 * In-memory hub WebSocket-соединений.
 *
 * Один пользователь может быть подключён с нескольких устройств (mobile + web),
 * поэтому храним Set<WebSocket> на userId.
 *
 * Для multi-instance backend нужно будет вынести в Redis pub/sub, но для
 * single-instance fastify этого достаточно.
 */

type WS = { send: (data: string) => void; close: () => void }

const connections: Map<string, Set<WS>> = new Map()

export function addConnection(userId: string, ws: WS) {
  let set = connections.get(userId)
  if (!set) {
    set = new Set()
    connections.set(userId, set)
  }
  set.add(ws)
}

export function removeConnection(userId: string, ws: WS) {
  const set = connections.get(userId)
  if (!set) return
  set.delete(ws)
  if (set.size === 0) connections.delete(userId)
}

export function isOnline(userId: string): boolean {
  const set = connections.get(userId)
  return !!set && set.size > 0
}

export function sendToUser(userId: string, message: object) {
  const set = connections.get(userId)
  if (!set) return
  const payload = JSON.stringify(message)
  set.forEach((ws) => {
    try {
      ws.send(payload)
    } catch (_) {
      // ignore — disconnect-handler удалит
    }
  })
}
