import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

abstract class AuthTokenStore {
  Future<StoredAuthTokens?> read();

  Future<void> write(StoredAuthTokens tokens);

  Future<void> clear();
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore({required FlutterSecureStorage secureStorage})
    : _secureStorage = secureStorage;

  static const String _userIdKey = 'auth.user_id';
  static const String _accessTokenKey = 'auth.access_token';
  static const String _accessTokenExpiresAtKey = 'auth.access_token_expires_at';
  static const String _refreshTokenKey = 'auth.refresh_token';
  static const String _refreshTokenExpiresAtKey =
      'auth.refresh_token_expires_at';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<StoredAuthTokens?> read() async {
    final values = await _secureStorage.readAll();
    final userId = values[_userIdKey]?.trim() ?? '';
    final accessToken = values[_accessTokenKey]?.trim() ?? '';
    final accessTokenExpiresAtRaw =
        values[_accessTokenExpiresAtKey]?.trim() ?? '';
    final refreshToken = values[_refreshTokenKey]?.trim() ?? '';
    final refreshTokenExpiresAtRaw =
        values[_refreshTokenExpiresAtKey]?.trim() ?? '';

    if (userId.isEmpty ||
        accessToken.isEmpty ||
        accessTokenExpiresAtRaw.isEmpty ||
        refreshToken.isEmpty ||
        refreshTokenExpiresAtRaw.isEmpty) {
      return null;
    }

    try {
      return StoredAuthTokens(
        userId: userId,
        accessToken: accessToken,
        accessTokenExpiresAt: DateTime.parse(accessTokenExpiresAtRaw).toUtc(),
        refreshToken: refreshToken,
        refreshTokenExpiresAt: DateTime.parse(refreshTokenExpiresAtRaw).toUtc(),
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredAuthTokens tokens) async {
    await _secureStorage.write(key: _userIdKey, value: tokens.userId);
    await _secureStorage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _secureStorage.write(
      key: _accessTokenExpiresAtKey,
      value: tokens.accessTokenExpiresAt.toUtc().toIso8601String(),
    );
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: tokens.refreshToken,
    );
    await _secureStorage.write(
      key: _refreshTokenExpiresAtKey,
      value: tokens.refreshTokenExpiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _accessTokenExpiresAtKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _refreshTokenExpiresAtKey);
  }
}
