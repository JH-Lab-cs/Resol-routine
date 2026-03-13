import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_repository.dart';
import 'package:resol_routine/features/auth/data/auth_token_store.dart';
import 'package:resol_routine/features/sync/data/device_identity_store.dart';
import 'package:resol_routine/features/sync/data/sync_outbox_repository.dart';

void main() {
  group('SyncOutboxRepository', () {
    test(
      'upserts repeated logical daily event and flush removes accepted row',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);

        final repository = SyncOutboxRepository(
          database: database,
          authRepository: _buildAuthRepository(
            client: MockClient((http.Request request) async {
              expect(request.url.path, '/sync/events');
              final body = jsonDecode(request.body) as Map<String, Object?>;
              final events = body['events'] as List<Object?>;
              expect(events, hasLength(1));
              final payload =
                  (events.first as Map<String, Object?>)['payload']
                      as Map<String, Object?>;
              expect(payload['selectedAnswer'], 'C');
              return http.Response(
                jsonEncode(<String, Object?>{
                  'summary': <String, Object?>{
                    'accepted': 1,
                    'duplicate': 0,
                    'invalid': 0,
                    'total': 1,
                  },
                  'results': <Object?>[
                    <String, Object?>{
                      'status': 'accepted',
                      'detail_code': null,
                    },
                  ],
                }),
                200,
                headers: <String, String>{'content-type': 'application/json'},
              );
            }),
          ),
          deviceIdentityStore: const _FakeDeviceIdentityStore(),
        );

        await repository.enqueueDailyAttemptSaved(
          backendUserId: 'student-1',
          sessionId: 10,
          questionId: 'q-1',
          selectedAnswer: 'A',
          isCorrect: false,
          wrongReasonTag: 'VOCAB',
        );
        await repository.enqueueDailyAttemptSaved(
          backendUserId: 'student-1',
          sessionId: 10,
          questionId: 'q-1',
          selectedAnswer: 'C',
          isCorrect: true,
          wrongReasonTag: null,
        );

        final beforeRows = await database
            .select(database.syncOutboxItems)
            .get();
        expect(beforeRows, hasLength(1));

        final result = await repository.flushPending(
          backendUserId: 'student-1',
        );

        expect(result.accepted, 1);
        expect(result.remaining, 0);
        final afterRows = await database.select(database.syncOutboxItems).get();
        expect(afterRows, isEmpty);
      },
    );

    test('duplicate backend response removes row without retrying', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final repository = SyncOutboxRepository(
        database: database,
        authRepository: _buildAuthRepository(
          client: MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(<String, Object?>{
                'summary': <String, Object?>{
                  'accepted': 0,
                  'duplicate': 1,
                  'invalid': 0,
                  'total': 1,
                },
                'results': <Object?>[
                  <String, Object?>{
                    'status': 'duplicate',
                    'detail_code': 'duplicate_idempotency_key',
                  },
                ],
              }),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        deviceIdentityStore: const _FakeDeviceIdentityStore(),
      );

      await repository.enqueueVocabQuizCompleted(
        backendUserId: 'student-1',
        dayKey: '20260313',
        track: 'M3',
        totalCount: 20,
        correctCount: 16,
        wrongVocabIds: const <String>['v1', 'v2', 'v3', 'v4'],
      );

      final result = await repository.flushPending(backendUserId: 'student-1');
      expect(result.duplicate, 1);
      expect(await database.select(database.syncOutboxItems).get(), isEmpty);
    });

    test('request failure keeps row and schedules retry', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final repository = SyncOutboxRepository(
        database: database,
        authRepository: _buildAuthRepository(
          client: MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(<String, Object?>{
                'detail': 'server_error',
                'errorCode': 'server_error',
              }),
              500,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }),
        ),
        deviceIdentityStore: const _FakeDeviceIdentityStore(),
      );

      await repository.enqueueMockExamCompleted(
        backendUserId: 'student-1',
        mockSessionId: 77,
        examType: 'WEEKLY',
        periodKey: '2026-W11',
        track: 'H1',
        plannedItems: 20,
        completedItems: 20,
        listeningCorrectCount: 8,
        readingCorrectCount: 9,
        wrongCount: 3,
      );

      final result = await repository.flushPending(backendUserId: 'student-1');
      expect(result.failed, 1);

      final rows = await database.select(database.syncOutboxItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.retryCount, 1);
      expect(rows.single.lastErrorCode, 'server_error');
      expect(rows.single.nextRetryAt, isNotNull);
    });
  });
}

class _FakeDeviceIdentityStore implements DeviceIdentityStore {
  const _FakeDeviceIdentityStore();

  @override
  Future<String> getOrCreateDeviceId() async => 'device-sync-test';
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

AuthRepository _buildAuthRepository({required http.Client client}) {
  return AuthRepository(
    apiClient: JsonApiClient(
      baseUrl: 'https://example.test',
      httpClient: client,
    ),
    tokenStore: _InMemoryAuthTokenStore(
      initialTokens: StoredAuthTokens(
        userId: 'student-1',
        accessToken: 'access-token',
        accessTokenExpiresAt: DateTime.utc(2026, 3, 30),
        refreshToken: 'refresh-token',
        refreshTokenExpiresAt: DateTime.utc(2026, 4, 30),
      ),
    ),
  );
}
