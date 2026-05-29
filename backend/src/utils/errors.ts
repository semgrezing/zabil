export class AppError extends Error {
  constructor(
    public readonly message: string,
    public readonly statusCode: number = 400,
    public readonly code?: string
  ) {
    super(message)
    this.name = 'AppError'
  }
}

export const errors = {
  unauthorized: () => new AppError('Не авторизован', 401, 'UNAUTHORIZED'),
  forbidden: () => new AppError('Нет доступа', 403, 'FORBIDDEN'),
  notFound: (entity = 'Ресурс') => new AppError(`${entity} не найден`, 404, 'NOT_FOUND'),
  conflict: (msg: string) => new AppError(msg, 409, 'CONFLICT'),
  badRequest: (msg: string) => new AppError(msg, 400, 'BAD_REQUEST'),
}
