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

/**
 * Note-level presence: noteId → Set of userIds currently viewing the note.
 */
const notePresence: Map<string, Set<string>> = new Map()

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

// ── Note presence ──────────────────────────────────────────────

/**
 * Mark a user as viewing a note.
 * Returns the current set of viewer userIds (including the new one).
 */
export function joinNote(userId: string, noteId: string): string[] {
  let viewers = notePresence.get(noteId)
  if (!viewers) {
    viewers = new Set()
    notePresence.set(noteId, viewers)
  }
  viewers.add(userId)
  return Array.from(viewers)
}

/**
 * Remove a user from a note's viewer set.
 */
export function leaveNote(userId: string, noteId: string) {
  const viewers = notePresence.get(noteId)
  if (!viewers) return
  viewers.delete(userId)
  if (viewers.size === 0) notePresence.delete(noteId)
}

/**
 * Remove a user from ALL notes they are viewing (call on disconnect).
 * Returns the noteIds they were removed from so the caller can broadcast.
 */
export function leaveAllNotes(userId: string): string[] {
  const leftNotes: string[] = []
  for (const [noteId, viewers] of notePresence) {
    if (viewers.has(userId)) {
      viewers.delete(userId)
      leftNotes.push(noteId)
      if (viewers.size === 0) notePresence.delete(noteId)
    }
  }
  return leftNotes
}

/**
 * Get all userIds currently viewing a note.
 */
export function getNoteViewers(noteId: string): Set<string> {
  return notePresence.get(noteId) ?? new Set()
}

/**
 * Send a message to every user viewing a note EXCEPT the sender.
 */
export function broadcastToNote(noteId: string, senderUserId: string, message: object) {
  const viewers = notePresence.get(noteId)
  if (!viewers) return
  for (const uid of viewers) {
    if (uid === senderUserId) continue
    sendToUser(uid, message)
  }
}
