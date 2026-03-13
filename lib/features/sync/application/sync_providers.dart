import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../auth/data/auth_models.dart';
import '../data/device_identity_store.dart';
import '../data/sync_models.dart';
import '../data/sync_outbox_repository.dart';

enum SyncFlushStatus { idle, syncing, success, error }

class SyncFlushState {
  const SyncFlushState({
    required this.status,
    required this.pendingCount,
    this.errorCode,
    this.errorMessage,
    this.lastResult,
  });

  const SyncFlushState.idle()
    : status = SyncFlushStatus.idle,
      pendingCount = 0,
      errorCode = null,
      errorMessage = null,
      lastResult = null;

  final SyncFlushStatus status;
  final int pendingCount;
  final String? errorCode;
  final String? errorMessage;
  final SyncFlushResult? lastResult;

  SyncFlushState copyWith({
    SyncFlushStatus? status,
    int? pendingCount,
    String? errorCode,
    bool clearErrorCode = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    SyncFlushResult? lastResult,
    bool clearLastResult = false,
  }) {
    return SyncFlushState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
    );
  }
}

final deviceIdentityStoreProvider = Provider<DeviceIdentityStore>((Ref ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return SecureDeviceIdentityStore(secureStorage: secureStorage);
});

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  final deviceIdentityStore = ref.watch(deviceIdentityStoreProvider);
  return SyncOutboxRepository(
    database: database,
    authRepository: authRepository,
    deviceIdentityStore: deviceIdentityStore,
  );
});

final syncPendingCountProvider = StreamProvider<int>((Ref ref) {
  final authState = ref.watch(authSessionProvider);
  if (!authState.isSignedIn || authState.user?.role != AuthUserRole.student) {
    return Stream<int>.value(0);
  }
  return ref
      .watch(syncOutboxRepositoryProvider)
      .watchPendingCount(backendUserId: authState.user!.id);
});

class SyncFlushNotifier extends Notifier<SyncFlushState> {
  @override
  SyncFlushState build() {
    ref.listen<AsyncValue<int>>(syncPendingCountProvider, (previous, next) {
      final count = next.valueOrNull;
      if (count != null) {
        state = state.copyWith(pendingCount: count);
      }
    });
    return const SyncFlushState.idle();
  }

  Future<void> recordDailyAttemptSaved({
    required int sessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    required String? wrongReasonTag,
  }) async {
    final user = _requireSignedInStudent();
    if (user == null) {
      return;
    }
    await ref
        .read(syncOutboxRepositoryProvider)
        .enqueueDailyAttemptSaved(
          backendUserId: user.id,
          sessionId: sessionId,
          questionId: questionId,
          selectedAnswer: selectedAnswer,
          isCorrect: isCorrect,
          wrongReasonTag: wrongReasonTag,
        );
    await _refreshPendingCount(user.id);
    await flushNow();
  }

  Future<void> recordVocabQuizCompleted({
    required String dayKey,
    required String track,
    required int totalCount,
    required int correctCount,
    required List<String> wrongVocabIds,
  }) async {
    final user = _requireSignedInStudent();
    if (user == null) {
      return;
    }
    await ref
        .read(syncOutboxRepositoryProvider)
        .enqueueVocabQuizCompleted(
          backendUserId: user.id,
          dayKey: dayKey,
          track: track,
          totalCount: totalCount,
          correctCount: correctCount,
          wrongVocabIds: wrongVocabIds,
        );
    await _refreshPendingCount(user.id);
    await flushNow();
  }

  Future<void> recordMockExamCompleted({
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
    final user = _requireSignedInStudent();
    if (user == null) {
      return;
    }
    await ref
        .read(syncOutboxRepositoryProvider)
        .enqueueMockExamCompleted(
          backendUserId: user.id,
          mockSessionId: mockSessionId,
          examType: examType,
          periodKey: periodKey,
          track: track,
          plannedItems: plannedItems,
          completedItems: completedItems,
          listeningCorrectCount: listeningCorrectCount,
          readingCorrectCount: readingCorrectCount,
          wrongCount: wrongCount,
        );
    await _refreshPendingCount(user.id);
    await flushNow();
  }

  Future<SyncFlushResult> flushNow() async {
    final user = _requireSignedInStudent();
    if (user == null) {
      state = state.copyWith(
        status: SyncFlushStatus.idle,
        pendingCount: 0,
        clearErrorCode: true,
        clearErrorMessage: true,
        clearLastResult: true,
      );
      return const SyncFlushResult(
        attempted: 0,
        accepted: 0,
        duplicate: 0,
        invalid: 0,
        failed: 0,
        remaining: 0,
        lastErrorCode: null,
      );
    }

    state = state.copyWith(
      status: SyncFlushStatus.syncing,
      clearErrorCode: true,
      clearErrorMessage: true,
    );

    try {
      final result = await ref
          .read(syncOutboxRepositoryProvider)
          .flushPending(backendUserId: user.id);
      state = state.copyWith(
        status: result.failed > 0 || result.invalid > 0
            ? SyncFlushStatus.error
            : SyncFlushStatus.success,
        pendingCount: result.remaining,
        errorCode: result.lastErrorCode,
        errorMessage: _toUiMessage(result.lastErrorCode),
        lastResult: result,
      );
      return result;
    } on AuthRepositoryException catch (error) {
      if (error.isUnauthorized) {
        await ref.read(authSessionProvider.notifier).signOut();
      }
      state = state.copyWith(
        status: SyncFlushStatus.error,
        errorCode: error.code,
        errorMessage: _toUiMessage(error.code),
      );
      rethrow;
    } catch (error) {
      state = state.copyWith(
        status: SyncFlushStatus.error,
        errorCode: 'sync_request_failed',
        errorMessage: _toUiMessage('sync_request_failed'),
      );
      rethrow;
    }
  }

  AuthUserProfile? _requireSignedInStudent() {
    final authState = ref.read(authSessionProvider);
    final user = authState.user;
    if (!authState.isSignedIn || user == null) {
      return null;
    }
    if (user.role != AuthUserRole.student) {
      return null;
    }
    return user;
  }

  Future<void> _refreshPendingCount(String backendUserId) async {
    final count = await ref
        .read(syncOutboxRepositoryProvider)
        .loadPendingCount(backendUserId: backendUserId);
    state = state.copyWith(pendingCount: count);
  }

  String _toUiMessage(String? code) {
    switch (code) {
      case 'invalid_access_token':
      case 'invalid_refresh_token':
      case 'refresh_token_reuse_detected':
        return '세션이 만료되어 다시 로그인해야 합니다.';
      case 'sync_request_failed':
        return '학습 기록 업로드에 실패했습니다. 네트워크를 확인해 주세요.';
      case 'sync_item_invalid':
      case 'sync_response_invalid':
        return '학습 기록 형식이 올바르지 않아 업로드하지 못했습니다.';
      default:
        return '학습 기록 업로드를 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}

final syncFlushControllerProvider =
    NotifierProvider<SyncFlushNotifier, SyncFlushState>(SyncFlushNotifier.new);
