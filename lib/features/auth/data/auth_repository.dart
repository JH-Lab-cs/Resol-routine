import '../../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_token_store.dart';

class AuthRepository {
  AuthRepository({
    required JsonApiClient apiClient,
    required AuthTokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final JsonApiClient _apiClient;
  final AuthTokenStore _tokenStore;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: <String, Object?>{'email': email.trim(), 'password': password},
    );
    final body = _requireSuccessBody(response);
    final session = _parseSession(body);
    await _tokenStore.write(_toStoredTokens(session));
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final storedTokens = await _tokenStore.read();
    if (storedTokens == null) {
      return null;
    }

    try {
      final user = await fetchCurrentUser();
      final refreshedTokens = await _requireStoredTokens();
      return AuthSession(tokens: _toAuthTokens(refreshedTokens), user: user);
    } on AuthRepositoryException catch (error) {
      if (error.isUnauthorized) {
        await clearSession();
        return null;
      }
      rethrow;
    }
  }

  Future<AuthSession> refreshSession() async {
    final refreshedTokens = await _refreshTokensInternal();
    final user = await fetchCurrentUser(retryOnUnauthorized: false);
    return AuthSession(tokens: _toAuthTokens(refreshedTokens), user: user);
  }

  Future<void> signOut() async {
    final storedTokens = await _tokenStore.read();
    if (storedTokens != null) {
      try {
        await _apiClient.post(
          '/auth/logout',
          headers: <String, String>{
            'Authorization': 'Bearer ${storedTokens.accessToken}',
          },
          body: <String, Object?>{
            'refresh_token': storedTokens.refreshToken,
            'all_devices': false,
          },
        );
      } catch (_) {
        // Local sign-out must complete even when the server call fails.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() => _tokenStore.clear();

  Future<AuthUserProfile> fetchCurrentUser({
    bool retryOnUnauthorized = true,
  }) async {
    final response = await _sendAuthorized(
      retryOnUnauthorized: retryOnUnauthorized,
      send: (String accessToken) {
        return _apiClient.get(
          '/users/me',
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        );
      },
    );
    final body = _requireSuccessBody(response);
    return _parseUser(body);
  }

  Future<JsonApiResponse> authorizedGet(
    String path, {
    bool retryOnUnauthorized = true,
  }) {
    return _sendAuthorized(
      retryOnUnauthorized: retryOnUnauthorized,
      send: (String accessToken) {
        return _apiClient.get(
          path,
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        );
      },
    );
  }

  Future<JsonApiResponse> authorizedPost(
    String path, {
    Object? body,
    bool retryOnUnauthorized = true,
  }) {
    return _sendAuthorized(
      retryOnUnauthorized: retryOnUnauthorized,
      send: (String accessToken) {
        return _apiClient.post(
          path,
          headers: <String, String>{'Authorization': 'Bearer $accessToken'},
          body: body,
        );
      },
    );
  }

  Future<JsonApiResponse> _sendAuthorized({
    required Future<JsonApiResponse> Function(String accessToken) send,
    required bool retryOnUnauthorized,
  }) async {
    final tokens = await _requireStoredTokens();
    final initialResponse = await send(tokens.accessToken);
    if (initialResponse.statusCode != 401 || !retryOnUnauthorized) {
      _throwIfError(initialResponse);
      return initialResponse;
    }

    final refreshedTokens = await _refreshTokensInternal();
    final retryResponse = await send(refreshedTokens.accessToken);
    _throwIfError(retryResponse);
    return retryResponse;
  }

  Future<StoredAuthTokens> _refreshTokensInternal() async {
    final tokens = await _requireStoredTokens();
    final response = await _apiClient.post(
      '/auth/refresh',
      body: <String, Object?>{'refresh_token': tokens.refreshToken},
    );
    if (response.statusCode >= 400) {
      final exception = _toException(response);
      if (exception.isUnauthorized) {
        await clearSession();
      }
      throw exception;
    }

    final body = _requireSuccessBody(response);
    final session = _parseSession(body);
    final refreshedTokens = _toStoredTokens(session);
    await _tokenStore.write(refreshedTokens);
    return refreshedTokens;
  }

  Future<StoredAuthTokens> _requireStoredTokens() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) {
      throw const AuthRepositoryException(
        code: 'missing_session',
        message: 'No stored auth session is available.',
      );
    }
    return tokens;
  }

  Map<String, Object?> _requireSuccessBody(JsonApiResponse response) {
    if (response.statusCode >= 400) {
      throw _toException(response);
    }
    final body = response.bodyAsMap;
    if (body.isEmpty) {
      throw AuthRepositoryException(
        code: 'invalid_response',
        message: 'The server returned an empty response body.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void _throwIfError(JsonApiResponse response) {
    if (response.statusCode >= 400) {
      throw _toException(response);
    }
  }

  AuthRepositoryException _toException(JsonApiResponse response) {
    final body = response.bodyAsMap;
    final code =
        body['errorCode']?.toString() ??
        body['detail']?.toString() ??
        'http_${response.statusCode}';
    final message = body['detail']?.toString() ?? 'Request failed.';
    return AuthRepositoryException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  AuthSession _parseSession(Map<String, Object?> body) {
    return AuthSession(
      tokens: AuthTokens(
        accessToken: _requiredString(body, 'access_token'),
        accessTokenExpiresAt: _requiredDateTime(
          body,
          'access_token_expires_at',
        ),
        refreshToken: _requiredString(body, 'refresh_token'),
        refreshTokenExpiresAt: _requiredDateTime(
          body,
          'refresh_token_expires_at',
        ),
      ),
      user: _parseUser(_requiredMap(body, 'user')),
    );
  }

  AuthUserProfile _parseUser(Map<String, Object?> body) {
    return AuthUserProfile(
      id: _requiredString(body, 'id'),
      email: _requiredString(body, 'email'),
      role: authUserRoleFromApi(_requiredString(body, 'role')),
      createdAt: _requiredDateTime(body, 'created_at'),
    );
  }

  StoredAuthTokens _toStoredTokens(AuthSession session) {
    return StoredAuthTokens(
      userId: session.user.id,
      accessToken: session.tokens.accessToken,
      accessTokenExpiresAt: session.tokens.accessTokenExpiresAt,
      refreshToken: session.tokens.refreshToken,
      refreshTokenExpiresAt: session.tokens.refreshTokenExpiresAt,
    );
  }

  AuthTokens _toAuthTokens(StoredAuthTokens stored) {
    return AuthTokens(
      accessToken: stored.accessToken,
      accessTokenExpiresAt: stored.accessTokenExpiresAt,
      refreshToken: stored.refreshToken,
      refreshTokenExpiresAt: stored.refreshTokenExpiresAt,
    );
  }

  String _requiredString(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw AuthRepositoryException(
      code: 'invalid_response',
      message: 'Missing required string field: $key',
    );
  }

  DateTime _requiredDateTime(Map<String, Object?> body, String key) {
    final raw = _requiredString(body, key);
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      throw AuthRepositoryException(
        code: 'invalid_response',
        message: 'Invalid datetime field: $key',
      );
    }
  }

  Map<String, Object?> _requiredMap(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    throw AuthRepositoryException(
      code: 'invalid_response',
      message: 'Missing required object field: $key',
    );
  }
}
