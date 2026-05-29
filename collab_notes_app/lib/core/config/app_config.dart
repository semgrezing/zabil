/// App configuration — change BASE_URL before build
class AppConfig {
  AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://api.achiemvemer.ru/api/v1',
  );

  /// Origin без `/api/v1` — для статики (uploads), сокетов и т.п.
  ///
  /// `https://api.achiemvemer.ru/api/v1` → `https://api.achiemvemer.ru`
  static String get apiOrigin {
    final uri = Uri.parse(baseUrl);
    final port = uri.hasPort && uri.port != 80 && uri.port != 443
        ? ':${uri.port}'
        : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}
