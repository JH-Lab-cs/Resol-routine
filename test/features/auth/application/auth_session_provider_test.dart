import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_token_store.dart';
import 'package:resol_routine/features/settings/application/user_settings_providers.dart';

void main() {
  group('AuthSessionNotifier', () {
    test(
      'bootstrap restores signed-in session and syncs role/profile identity',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);
        final tokenStore = _InMemoryAuthTokenStore(
          initialTokens: StoredAuthTokens(
            userId: 'student-1',
            accessToken: 'fresh-access',
            accessTokenExpiresAt: DateTime.utc(2026, 3, 12),
            refreshToken: 'refresh-token-1',
            refreshTokenExpiresAt: DateTime.utc(2026, 3, 20),
          ),
        );
        final container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            authTokenStoreProvider.overrideWithValue(tokenStore),
            httpClientProvider.overrideWithValue(
              MockClient((http.Request request) async {
                expect(request.url.path, '/users/me');
                return http.Response(
                  jsonEncode(<String, Object?>{
                    'id': 'student-1',
                    'email': 'student@example.com',
                    'role': 'STUDENT',
                    'created_at': '2026-03-01T12:00:00Z',
                  }),
                  200,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              }),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authSessionProvider.notifier).bootstrap();

        final authState = container.read(authSessionProvider);
        final settings = await container.read(userSettingsProvider.future);

        expect(authState.status, AuthSessionStatus.signedIn);
        expect(authState.user?.role, AuthUserRole.student);
        expect(settings.backendUserId, 'student-1');
        expect(settings.role, 'STUDENT');
        expect(settings.displayName, '');
      },
    );

    test('refresh failure signs out and clears storage', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final tokenStore = _InMemoryAuthTokenStore(
        initialTokens: StoredAuthTokens(
          userId: 'parent-1',
          accessToken: 'expired-access',
          accessTokenExpiresAt: DateTime.utc(2026, 3, 10),
          refreshToken: 'refresh-token-1',
          refreshTokenExpiresAt: DateTime.utc(2026, 3, 20),
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          authTokenStoreProvider.overrideWithValue(tokenStore),
          httpClientProvider.overrideWithValue(
            MockClient((http.Request request) async {
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
        ],
      );
      addTearDown(container.dispose);

      await container.read(authSessionProvider.notifier).bootstrap();

      final authState = container.read(authSessionProvider);
      final settings = await container.read(userSettingsProvider.future);

      expect(authState.status, AuthSessionStatus.signedOut);
      expect(await tokenStore.read(), isNull);
      expect(settings.backendUserId, '');
      expect(settings.displayName, '');
    });
  });
}

class _InMemoryAuthTokenStore implements AuthTokenStore {
  _InMemoryAuthTokenStore({StoredAuthTokens? initialTokens})
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
