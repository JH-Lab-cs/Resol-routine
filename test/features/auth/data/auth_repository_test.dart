import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_repository.dart';
import 'package:resol_routine/features/auth/data/auth_token_store.dart';

void main() {
  group('AuthRepository', () {
    test('login success stores tokens', () async {
      final tokenStore = InMemoryAuthTokenStore();
      final repository = AuthRepository(
        apiClient: JsonApiClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient((http.Request request) async {
            expect(request.url.path, '/auth/login');
            return http.Response(
              jsonEncode(_sessionJson(userId: 'student-1', role: 'STUDENT')),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        tokenStore: tokenStore,
      );

      final session = await repository.signIn(
        email: 'student@example.com',
        password: 'password123',
      );

      expect(session.user.id, 'student-1');
      expect(session.user.role, AuthUserRole.student);
      expect((await tokenStore.read())?.refreshToken, 'refresh-token-1');
    });

    test(
      'fetchCurrentUser refreshes once and retries original request',
      () async {
        final tokenStore = InMemoryAuthTokenStore(
          initialTokens: StoredAuthTokens(
            userId: 'student-1',
            accessToken: 'expired-access',
            accessTokenExpiresAt: DateTime.utc(2026, 3, 10),
            refreshToken: 'refresh-token-1',
            refreshTokenExpiresAt: DateTime.utc(2026, 3, 20),
          ),
        );
        var meCalls = 0;
        final repository = AuthRepository(
          apiClient: JsonApiClient(
            baseUrl: 'http://example.test',
            httpClient: MockClient((http.Request request) async {
              if (request.url.path == '/users/me') {
                meCalls += 1;
                final authHeader = request.headers['authorization'];
                if (authHeader == 'Bearer expired-access') {
                  return http.Response(
                    jsonEncode(<String, Object?>{
                      'detail': 'invalid_access_token',
                      'errorCode': 'invalid_access_token',
                    }),
                    401,
                    headers: <String, String>{
                      'content-type': 'application/json',
                    },
                  );
                }
                expect(authHeader, 'Bearer fresh-access');
                return http.Response(
                  jsonEncode(_userJson(userId: 'student-1', role: 'STUDENT')),
                  200,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              }

              expect(request.url.path, '/auth/refresh');
              return http.Response(
                jsonEncode(_sessionJson(userId: 'student-1', role: 'STUDENT')),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }),
          ),
          tokenStore: tokenStore,
        );

        final user = await repository.fetchCurrentUser();

        expect(user.id, 'student-1');
        expect(meCalls, 2);
        expect((await tokenStore.read())?.accessToken, 'fresh-access');
      },
    );

    test('restoreSession clears storage when refresh fails', () async {
      final tokenStore = InMemoryAuthTokenStore(
        initialTokens: StoredAuthTokens(
          userId: 'student-1',
          accessToken: 'expired-access',
          accessTokenExpiresAt: DateTime.utc(2026, 3, 10),
          refreshToken: 'refresh-token-1',
          refreshTokenExpiresAt: DateTime.utc(2026, 3, 20),
        ),
      );
      final repository = AuthRepository(
        apiClient: JsonApiClient(
          baseUrl: 'http://example.test',
          httpClient: MockClient((http.Request request) async {
            if (request.url.path == '/users/me') {
              return http.Response(
                jsonEncode(<String, Object?>{
                  'detail': 'invalid_access_token',
                  'errorCode': 'invalid_access_token',
                }),
                401,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }

            return http.Response(
              jsonEncode(<String, Object?>{
                'detail': 'invalid_refresh_token',
                'errorCode': 'invalid_refresh_token',
              }),
              401,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        tokenStore: tokenStore,
      );

      final session = await repository.restoreSession();

      expect(session, isNull);
      expect(await tokenStore.read(), isNull);
    });
  });
}

class InMemoryAuthTokenStore implements AuthTokenStore {
  InMemoryAuthTokenStore({StoredAuthTokens? initialTokens})
    : _tokens = initialTokens;

  StoredAuthTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredAuthTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredAuthTokens tokens) async {
    _tokens = tokens;
  }
}

Map<String, Object?> _sessionJson({
  required String userId,
  required String role,
}) {
  return <String, Object?>{
    'access_token': 'fresh-access',
    'access_token_expires_at': '2026-03-11T12:00:00Z',
    'refresh_token': 'refresh-token-1',
    'refresh_token_expires_at': '2026-03-18T12:00:00Z',
    'user': _userJson(userId: userId, role: role),
  };
}

Map<String, Object?> _userJson({required String userId, required String role}) {
  return <String, Object?>{
    'id': userId,
    'email': 'student@example.com',
    'role': role,
    'created_at': '2026-03-01T12:00:00Z',
  };
}
