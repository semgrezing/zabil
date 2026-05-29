import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  // On desktop (Windows/Linux/macOS) use SharedPreferences to avoid ATL dependency.
  // On mobile (Android/iOS) use FlutterSecureStorage for proper keychain/keystore.
  static bool get _useSecure =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_useSecure) {
      await Future.wait([
        _storage.write(key: _accessKey, value: accessToken),
        _storage.write(key: _refreshKey, value: refreshToken),
      ]);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_accessKey, accessToken),
        prefs.setString(_refreshKey, refreshToken),
      ]);
    }
  }

  Future<String?> getAccessToken() async {
    if (_useSecure) return _storage.read(key: _accessKey);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> getRefreshToken() async {
    if (_useSecure) return _storage.read(key: _refreshKey);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clearTokens() async {
    if (_useSecure) {
      await Future.wait([
        _storage.delete(key: _accessKey),
        _storage.delete(key: _refreshKey),
      ]);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_accessKey),
        prefs.remove(_refreshKey),
      ]);
    }
  }
}
