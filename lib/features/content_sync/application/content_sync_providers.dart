import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../auth/data/auth_models.dart';
import '../../settings/application/user_settings_providers.dart' as settings;
import '../data/content_sync_models.dart';
import '../data/content_sync_repository.dart';

final publishedContentSyncRepositoryProvider =
    Provider<PublishedContentSyncRepository>((Ref ref) {
      final database = ref.watch(appDatabaseProvider);
      final apiClient = ref.watch(jsonApiClientProvider);
      return PublishedContentSyncRepository(database: database, apiClient: apiClient);
    });

final publishedContentSyncSnapshotProvider =
    FutureProvider.family<PublishedContentSyncSnapshot, String>((
      Ref ref,
      String track,
    ) {
      return ref
          .watch(publishedContentSyncRepositoryProvider)
          .getSnapshot(track: track);
    });

enum PublishedContentSyncStatus { idle, syncing, success, error }

class PublishedContentSyncState {
  const PublishedContentSyncState({
    required this.status,
    this.track,
    this.errorCode,
    this.errorMessage,
    this.lastResult,
  });

  const PublishedContentSyncState.idle()
    : status = PublishedContentSyncStatus.idle,
      track = null,
      errorCode = null,
      errorMessage = null,
      lastResult = null;

  final PublishedContentSyncStatus status;
  final String? track;
  final String? errorCode;
  final String? errorMessage;
  final PublishedContentSyncResult? lastResult;

  PublishedContentSyncState copyWith({
    PublishedContentSyncStatus? status,
    String? track,
    String? errorCode,
    bool clearErrorCode = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    PublishedContentSyncResult? lastResult,
    bool clearLastResult = false,
  }) {
    return PublishedContentSyncState(
      status: status ?? this.status,
      track: track ?? this.track,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
    );
  }
}

class PublishedContentSyncController extends Notifier<PublishedContentSyncState> {
  @override
  PublishedContentSyncState build() {
    ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      if (!next.isSignedIn || next.user?.role != AuthUserRole.student) {
        state = const PublishedContentSyncState.idle();
        return;
      }
      final track = ref.read(settings.selectedTrackProvider);
      unawaited(_refreshSnapshot(track: track));
    });
    ref.listen<String>(settings.selectedTrackProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      final authState = ref.read(authSessionProvider);
      if (!authState.isSignedIn || authState.user?.role != AuthUserRole.student) {
        return;
      }
      unawaited(_refreshSnapshot(track: next));
    });
    return const PublishedContentSyncState.idle();
  }

  Future<PublishedContentSyncResult?> syncCurrentTrack() async {
    final authState = ref.read(authSessionProvider);
    if (!authState.isSignedIn || authState.user?.role != AuthUserRole.student) {
      state = const PublishedContentSyncState.idle();
      return null;
    }
    final track = ref.read(settings.selectedTrackProvider);
    return syncTrack(track: track);
  }

  Future<PublishedContentSyncResult?> syncTrack({required String track}) async {
    final authState = ref.read(authSessionProvider);
    if (!authState.isSignedIn || authState.user?.role != AuthUserRole.student) {
      state = const PublishedContentSyncState.idle();
      return null;
    }
    if (state.status == PublishedContentSyncStatus.syncing && state.track == track) {
      return state.lastResult;
    }

    state = state.copyWith(
      status: PublishedContentSyncStatus.syncing,
      track: track,
      clearErrorCode: true,
      clearErrorMessage: true,
    );

    try {
      final result = await ref
          .read(publishedContentSyncRepositoryProvider)
          .syncTrack(track: track);
      ref.invalidate(publishedContentSyncSnapshotProvider(track));
      state = state.copyWith(
        status: PublishedContentSyncStatus.success,
        track: track,
        lastResult: result,
        clearErrorCode: true,
        clearErrorMessage: true,
      );
      return result;
    } on ContentSyncException catch (error) {
      ref.invalidate(publishedContentSyncSnapshotProvider(track));
      state = state.copyWith(
        status: PublishedContentSyncStatus.error,
        track: track,
        errorCode: error.code,
        errorMessage: _toUiMessage(error),
      );
      return null;
    } on FormatException catch (error) {
      ref.invalidate(publishedContentSyncSnapshotProvider(track));
      state = state.copyWith(
        status: PublishedContentSyncStatus.error,
        track: track,
        errorCode: 'invalid_response',
        errorMessage: error.message,
      );
      return null;
    } on Object {
      ref.invalidate(publishedContentSyncSnapshotProvider(track));
      state = state.copyWith(
        status: PublishedContentSyncStatus.error,
        track: track,
        errorCode: 'content_sync_transport_failed',
        errorMessage: '콘텐츠 동기화에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      );
      return null;
    }
  }

  Future<void> _refreshSnapshot({required String track}) async {
    try {
      final snapshot = await ref.read(
        publishedContentSyncRepositoryProvider,
      ).getSnapshot(track: track);
      if (state.status == PublishedContentSyncStatus.syncing) {
        return;
      }
      state = state.copyWith(
        track: track,
        status: snapshot.lastSyncErrorCode == null
            ? PublishedContentSyncStatus.idle
            : PublishedContentSyncStatus.error,
        errorCode: snapshot.lastSyncErrorCode,
        clearErrorCode: snapshot.lastSyncErrorCode == null,
        errorMessage: snapshot.lastSyncErrorCode == null
            ? null
            : _toUiMessage(
                ContentSyncException(
                  code: snapshot.lastSyncErrorCode!,
                  message: snapshot.lastSyncErrorCode!,
                ),
              ),
        clearErrorMessage: snapshot.lastSyncErrorCode == null,
      );
    } catch (_) {
      // Leave the previous controller state untouched for passive refreshes.
    }
  }

  String _toUiMessage(ContentSyncException error) {
    switch (error.code) {
      case 'invalid_sync_cursor':
        return '콘텐츠 동기화 기준점이 올바르지 않습니다.';
      case 'invalid_response':
        return '콘텐츠 동기화 응답 형식이 올바르지 않습니다.';
      default:
        if (error.isServerUnavailable) {
          return '콘텐츠 서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.';
        }
        return '콘텐츠 동기화에 실패했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}

final publishedContentSyncControllerProvider =
    NotifierProvider<PublishedContentSyncController, PublishedContentSyncState>(
      PublishedContentSyncController.new,
    );
