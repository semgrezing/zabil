import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/config/api_endpoints.dart';
import '../models/auth_models.dart';

class AuthService {
  final Dio _dio = ApiClient.create();
  final TokenStorage _storage = TokenStorage();

  Future<AuthState> register(String username, String password) async {
    final response = await _dio.post(
      ApiEndpoints.register,
      data: {'username': username, 'password': password},
    );
    return _handleAuthResponse(response.data);
  }

  Future<AuthState> login(String username, String password) async {
    final response = await _dio.post(
      ApiEndpoints.login,
      data: {'username': username, 'password': password},
    );
    return _handleAuthResponse(response.data);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post(ApiEndpoints.logout, data: {'refreshToken': refreshToken});
    } catch (_) {
      // Best-effort logout — clear tokens regardless
    }
    await _storage.clearTokens();
  }

  Future<AuthState?> restoreSession() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null) return null;

    // Try to get current user info from token payload (simple JWT decode)
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;

      final payload = _decodeBase64(parts[1]);
      final userId = payload['userId'] as String?;
      final username = payload['username'] as String?;
      final exp = payload['exp'] as int?;

      if (userId == null || username == null) return null;

      final isExpired = exp != null &&
          DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());

      if (isExpired) {
        // Token expired — try refresh
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) return null;

        final freshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
        final response = await freshDio.post(
          ApiEndpoints.refresh,
          data: {'refreshToken': refreshToken},
        );
        await _storage.saveTokens(
          accessToken: response.data['accessToken'] as String,
          refreshToken: response.data['refreshToken'] as String,
        );
        return restoreSession();
      }

      try {
        final me = await _dio.get(ApiEndpoints.userMe);
        final user = UserModel.fromJson(me.data as Map<String, dynamic>);
        return AuthState.loggedIn(user);
      } catch (_) {
        return AuthState.loggedIn(UserModel(id: userId, username: username));
      }
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> updateProfile({
    String? displayName,
    bool? notePushEnabled,
    bool? checklistPushEnabled,
    bool? releasePushEnabled,
  }) async {
    final response = await _dio.patch(
      ApiEndpoints.userMe,
      data: {
        if (displayName != null || displayName == null) 'displayName': displayName,
        if (notePushEnabled != null) 'notePushEnabled': notePushEnabled,
        if (checklistPushEnabled != null) 'checklistPushEnabled': checklistPushEnabled,
        if (releasePushEnabled != null) 'releasePushEnabled': releasePushEnabled,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserModel> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      ApiEndpoints.userAvatar,
      data: formData,
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAvatar() async {
    await _dio.delete(ApiEndpoints.userAvatar);
  }

  Future<List<Map<String, dynamic>>> getAvatarHistory() async {
    final response = await _dio.get(ApiEndpoints.userAvatarHistory);
    return (response.data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> deleteAvatarHistoryItem(String historyId) async {
    await _dio.delete(ApiEndpoints.userAvatarHistoryItem(historyId));
  }

  Future<AuthState> _handleAuthResponse(Map<String, dynamic> data) async {
    final tokens = AuthTokens.fromJson(data);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return AuthState.loggedIn(user);
  }

  Map<String, dynamic> _decodeBase64(String base64) {
    var normalized = base64.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final bytes = base64Decode(normalized);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}


