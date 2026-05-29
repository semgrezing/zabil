import { FastifyInstance } from 'fastify'

export async function authenticate(request: any, reply: any) {
  try {
    await request.jwtVerify()
  } catch {
    reply.status(401).send({ error: 'Не авторизован', code: 'UNAUTHORIZED' })
  }
}

// Verify user is a member of the given group
export async function requireGroupMember(
  app: FastifyInstance,
  userId: string,
  groupId: string
): Promise<boolean> {
  const member = await app.prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId } },
  })
  return member !== null
}
