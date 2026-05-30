import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../config/api_endpoints.dart';
import '../auth/token_storage.dart';

class ApiClient {
  ApiClient._();

  static Future<String?>? _refreshFuture;
  static bool sessionInvalidated = false;
  static final ValueNotifier<int> sessionEpoch = ValueNotifier<int>(0);

  static void markSessionActive() {
    if (!sessionInvalidated) return;
    sessionInvalidated = false;
    sessionEpoch.value = sessionEpoch.value + 1;
  }

  static Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final _tokenStorage = TokenStorage();

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final token = await _refreshOrInvalidate();
    if (token == null) {
      handler.next(err);
      return;
    }

    try {
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $token';
      final retryResponse = await _dio.fetch(opts);
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshOrInvalidate() async {
    ApiClient._refreshFuture ??= _refreshAccessToken(_tokenStorage);
    final token = await ApiClient._refreshFuture;
    ApiClient._refreshFuture = null;
    return token;
  }

  Future<String?> _refreshAccessToken(TokenStorage storage) async {
    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null) {
        await storage.clearTokens();
        ApiClient.sessionInvalidated = true;
        ApiClient.sessionEpoch.value = ApiClient.sessionEpoch.value + 1;
        return null;
      }

      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken = response.data['accessToken'] as String;
      final newRefreshToken = response.data['refreshToken'] as String;

      await storage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      ApiClient.sessionInvalidated = false;
      return newAccessToken;
    } catch (_) {
      await storage.clearTokens();
      ApiClient.sessionInvalidated = true;
      ApiClient.sessionEpoch.value = ApiClient.sessionEpoch.value + 1;
      return null;
    }
  }
}
