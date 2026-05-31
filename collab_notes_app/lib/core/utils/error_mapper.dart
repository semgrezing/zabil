import 'package:dio/dio.dart';

/// Maps technical exceptions to user-friendly Russian messages.
String mapError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
        return 'Нет связи с сервером';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Сервер не отвечает';
      case DioExceptionType.cancel:
        return 'Запрос отменён';
      case DioExceptionType.badCertificate:
        return 'Проблема с сертификатом сервера';
      default:
        break;
    }
    final status = error.response?.statusCode;
    if (status == 401) return 'Необходимо войти снова';
    if (status == 403) return 'Нет доступа';
    if (status == 404) return 'Не найдено';
    if (status == 409) return 'Конфликт данных';
    if (status == 429) return 'Слишком много запросов. Попробуйте позже';
    if (status != null && status >= 500) return 'Ошибка на сервере';

    // Try to extract server error message
    final serverMsg = error.response?.data?['error']?.toString();
    if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;
  }

  final msg = error.toString();
  if (msg.contains('SocketException') || msg.contains('Connection refused')) {
    return 'Нет связи с сервером';
  }
  if (msg.contains('TimeoutException')) return 'Сервер не отвечает';

  return 'Что-то пошло не так';
}
