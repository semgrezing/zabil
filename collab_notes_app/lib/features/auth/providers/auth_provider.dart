import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/notifications/notification_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthService get _service => ref.read(authServiceProvider);

  @override
  Future<AuthState> build() async {
    final restored = await _service.restoreSession();
    if (restored?.isLoggedIn == true) {
      ApiClient.markSessionActive();
      // ignore: unawaited_futures
      NotificationService.registerWithBackend();
    }
    return restored ?? const AuthState.loggedOut();
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.login(username, password),
    );
    // После успешного входа регистрируем FCM-токен на бэке.
    if (state.valueOrNull?.isLoggedIn == true) {
      ApiClient.markSessionActive();
      // fire-and-forget — не блокируем UI и не показываем ошибки.
      // ignore: unawaited_futures
      NotificationService.registerWithBackend();
    }
  }

  Future<void> loginWithTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.loginWithTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    );
    if (state.valueOrNull?.isLoggedIn == true) {
      ApiClient.markSessionActive();
      // ignore: unawaited_futures
      NotificationService.registerWithBackend();
    }
  }

  Future<void> register(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.register(username, password),
    );
    if (state.valueOrNull?.isLoggedIn == true) {
      ApiClient.markSessionActive();
      // ignore: unawaited_futures
      NotificationService.registerWithBackend();
    }
  }

  Future<void> logout() async {
    final refreshToken = await TokenStorage().getRefreshToken();
    await _service.logout(refreshToken ?? '');
    state = const AsyncData(AuthState.loggedOut());
  }

  Future<UserModel?> updateDisplayName(String? displayName) async {
    final current = state.valueOrNull?.user;
    if (current == null) return null;
    final updated = await _service.updateProfile(displayName: displayName);
    state = AsyncData(AuthState.loggedIn(updated));
    return updated;
  }

  Future<UserModel?> updateUsername(String username) async {
    final current = state.valueOrNull?.user;
    if (current == null) return null;
    final updated = await _service.updateProfile(
      username: username,
      displayName: current.displayName,
    );
    state = AsyncData(AuthState.loggedIn(updated));
    return updated;
  }

  Future<UserModel?> uploadAvatar(String filePath) async {
    final current = state.valueOrNull?.user;
    if (current == null) return null;
    final updated = await _service.uploadAvatar(filePath);
    state = AsyncData(AuthState.loggedIn(updated));
    return updated;
  }

  Future<void> deleteAvatar() async {
    final current = state.valueOrNull?.user;
    if (current == null) return;
    await _service.deleteAvatar();
    state = AsyncData(AuthState.loggedIn(current.copyWith(avatarUrl: null)));
  }

  Future<UserModel?> updateNotificationPrefs({
    bool? notePushEnabled,
    bool? checklistPushEnabled,
    bool? releasePushEnabled,
  }) async {
    final current = state.valueOrNull?.user;
    if (current == null) return null;
    final updated = await _service.updateProfile(
      displayName: current.displayName,
      notePushEnabled: notePushEnabled,
      checklistPushEnabled: checklistPushEnabled,
      releasePushEnabled: releasePushEnabled,
    );
    state = AsyncData(AuthState.loggedIn(updated));
    return updated;
  }

  Future<List<Map<String, dynamic>>> getAvatarHistory() {
    return _service.getAvatarHistory();
  }

  Future<void> deleteAvatarHistoryItem(String historyId) {
    return _service.deleteAvatarHistoryItem(historyId);
  }
}
