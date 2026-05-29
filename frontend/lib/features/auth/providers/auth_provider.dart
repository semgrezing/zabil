import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../../../core/auth/token_storage.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final AuthService _service;

  @override
  Future<AuthState> build() async {
    _service = ref.read(authServiceProvider);
    final restored = await _service.restoreSession();
    return restored ?? const AuthState.loggedOut();
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.login(username, password),
    );
  }

  Future<void> register(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.register(username, password),
    );
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

  Future<UserModel?> uploadAvatar(String filePath) async {
    final current = state.valueOrNull?.user;
    if (current == null) return null;
    final updated = await _service.uploadAvatar(filePath);
    state = AsyncData(AuthState.loggedIn(updated));
    return updated;
  }
}
