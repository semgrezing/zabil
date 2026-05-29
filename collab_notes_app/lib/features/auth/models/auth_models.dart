import '../../../core/config/app_config.dart';

class UserModel {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  String get displayLabel {
    final name = displayName?.trim();
    return name != null && name.isNotEmpty ? name : username;
  }

  String? get avatarResolvedUrl {
    final raw = avatarUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${AppConfig.apiOrigin}$raw';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class AuthState {
  final UserModel? user;
  final bool isLoggedIn;

  const AuthState({this.user, this.isLoggedIn = false});

  AuthState.loggedIn(this.user) : isLoggedIn = true;

  const AuthState.loggedOut()
      : user = null,
        isLoggedIn = false;
}
