import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_repository.dart';
import 'package:resol_routine/features/auth/data/auth_token_store.dart';
import 'package:resol_routine/features/settings/application/user_settings_providers.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import 'package:resol_routine/features/sync/application/sync_providers.dart';
import 'package:resol_routine/features/sync/data/device_identity_store.dart';
import 'package:resol_routine/features/sync/data/sync_models.dart';
import 'package:resol_routine/features/sync/data/sync_outbox_repository.dart';

import '../../../test_helpers/fake_auth_session.dart';

void main() {
  group('SyncFlushNotifier', () {
    test('signed-out flush is a no-op', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          deviceIdentityStoreProvider.overrideWithValue(
            const _FakeDeviceIdentityStore(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(syncFlushControllerProvider.notifier)
          .flushNow();

      expect(result.attempted, 0);
      expect(container.read(syncFlushControllerProvider).pendingCount, 0);
    });

    test(
      'recordDailyAttemptSaved enqueues event and keeps pending sync state on failure',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);
        final fakeRepository = _FakeSyncOutboxRepository(
          database: database,
          pendingCount: 1,
          flushResult: const SyncFlushResult(
            attempted: 1,
            accepted: 0,
            duplicate: 0,
            invalid: 0,
            failed: 1,
            remaining: 1,
            lastErrorCode: 'server_error',
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            signedInAuthOverride(userId: 'student-1'),
            syncOutboxRepositoryProvider.overrideWithValue(fakeRepository),
            deviceIdentityStoreProvider.overrideWithValue(
              const _FakeDeviceIdentityStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(syncFlushControllerProvider.notifier)
            .recordDailyAttemptSaved(
              sessionId: 11,
              questionId: 'q-100',
              selectedAnswer: 'B',
              isCorrect: false,
              wrongReasonTag: 'EVIDENCE',
            );

        expect(fakeRepository.dailyAttemptCalls, hasLength(1));
        expect(fakeRepository.dailyAttemptCalls.single.sessionId, 11);
        expect(fakeRepository.flushCalls, 1);
        expect(container.read(syncFlushControllerProvider).pendingCount, 1);
      },
    );

    test(
      'recordMockExamCompleted enqueues event and keeps pending sync state on failure',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);
        final fakeRepository = _FakeSyncOutboxRepository(
          database: database,
          pendingCount: 1,
          flushResult: const SyncFlushResult(
            attempted: 1,
            accepted: 0,
            duplicate: 0,
            invalid: 0,
            failed: 1,
            remaining: 1,
            lastErrorCode: 'server_error',
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            signedInAuthOverride(userId: 'student-1'),
            syncOutboxRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(syncFlushControllerProvider.notifier)
            .recordMockExamCompleted(
              mockSessionId: 77,
              examType: 'WEEKLY',
              periodKey: '2026-W11',
              track: 'H1',
              plannedItems: 20,
              completedItems: 20,
              listeningCorrectCount: 9,
              readingCorrectCount: 8,
              wrongCount: 3,
            );

        expect(fakeRepository.mockExamCalls, hasLength(1));
        expect(fakeRepository.mockExamCalls.single.mockSessionId, 77);
        expect(fakeRepository.flushCalls, 1);
        expect(container.read(syncFlushControllerProvider).pendingCount, 1);
      },
    );

    test(
      'unauthorized flush signs out and clears local session state',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);
        final settingsRepository = containerlessSettingsRepo(database);
        await settingsRepository.syncAuthenticatedUser(
          backendUserId: 'student-1',
          role: 'STUDENT',
        );
        final fakeRepository = _FakeSyncOutboxRepository(
          database: database,
          pendingCount: 1,
          flushError: const AuthRepositoryException(
            code: 'invalid_access_token',
            message: 'invalid_access_token',
            statusCode: 401,
          ),
        );

        final container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            signedInAuthOverride(userId: 'student-1'),
            syncOutboxRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        try {
          await container.read(syncFlushControllerProvider.notifier).flushNow();
        } on AuthRepositoryException {
          // Unauthorized sync may rethrow after forcing sign-out.
        }

        expect(
          container.read(authSessionProvider).status,
          AuthSessionStatus.signedOut,
        );
        final settings = await container.read(userSettingsProvider.future);
        expect(settings.backendUserId, '');
      },
    );
  });
}

class _FakeDeviceIdentityStore implements DeviceIdentityStore {
  const _FakeDeviceIdentityStore();

  @override
  Future<String> getOrCreateDeviceId() async => 'device-sync-provider-test';
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

UserSettingsRepository containerlessSettingsRepo(AppDatabase database) {
  return UserSettingsRepository(database: database);
}

class _FakeSyncOutboxRepository extends SyncOutboxRepository {
  _FakeSyncOutboxRepository({
    required AppDatabase database,
    required this.pendingCount,
    this.flushResult,
    this.flushError,
  }) : super(
         database: database,
         authRepository: AuthRepository(
           apiClient: JsonApiClient(
             baseUrl: 'https://example.test',
             httpClient: _NoopHttpClient(),
           ),
           tokenStore: _InMemoryAuthTokenStore(),
         ),
         deviceIdentityStore: const _FakeDeviceIdentityStore(),
       );

  int pendingCount;
  final SyncFlushResult? flushResult;
  final Exception? flushError;
  int flushCalls = 0;
  final List<_DailyAttemptCall> dailyAttemptCalls = <_DailyAttemptCall>[];
  final List<_MockExamCall> mockExamCalls = <_MockExamCall>[];

  @override
  Future<int> loadPendingCount({required String backendUserId}) async {
    return pendingCount;
  }

  @override
  Future<void> enqueueDailyAttemptSaved({
    required String backendUserId,
    required int sessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    required String? wrongReasonTag,
  }) async {
    dailyAttemptCalls.add(
      _DailyAttemptCall(
        backendUserId: backendUserId,
        sessionId: sessionId,
        questionId: questionId,
      ),
    );
  }

  @override
  Future<void> enqueueMockExamCompleted({
    required String backendUserId,
    required int mockSessionId,
    required String examType,
    required String periodKey,
    required String track,
    required int plannedItems,
    required int completedItems,
    required int listeningCorrectCount,
    required int readingCorrectCount,
    required int wrongCount,
  }) async {
    mockExamCalls.add(
      _MockExamCall(
        backendUserId: backendUserId,
        mockSessionId: mockSessionId,
      ),
    );
  }

  @override
  Future<SyncFlushResult> flushPending({required String backendUserId}) async {
    flushCalls += 1;
    if (flushError != null) {
      throw flushError!;
    }
    return flushResult ??
        const SyncFlushResult(
          attempted: 0,
          accepted: 0,
          duplicate: 0,
          invalid: 0,
          failed: 0,
          remaining: 0,
          lastErrorCode: null,
        );
  }
}

class _DailyAttemptCall {
  const _DailyAttemptCall({
    required this.backendUserId,
    required this.sessionId,
    required this.questionId,
  });

  final String backendUserId;
  final int sessionId;
  final String questionId;
}

class _MockExamCall {
  const _MockExamCall({
    required this.backendUserId,
    required this.mockSessionId,
  });

  final String backendUserId;
  final int mockSessionId;
}

class _NoopHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    throw UnimplementedError('No network calls are expected in this fake.');
  }
}
