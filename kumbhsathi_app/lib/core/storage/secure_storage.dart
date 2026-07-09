import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Thin wrapper over flutter_secure_storage for auth tokens + cached user.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.kAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.kRefreshToken, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: AppConstants.kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: AppConstants.kRefreshToken);

  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: AppConstants.kUserJson, value: jsonEncode(user));

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: AppConstants.kUserJson);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> clear() => _storage.deleteAll();
}
