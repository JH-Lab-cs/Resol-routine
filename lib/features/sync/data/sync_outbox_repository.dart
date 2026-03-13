import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../auth/data/auth_models.dart';
import '../../../features/auth/data/auth_repository.dart';
import 'device_identity_store.dart';
import 'sync_models.dart';

class SyncOutboxRepository {
  SyncOutboxRepository({
    required AppDatabase database,
    required AuthRepository authRepository,
    required DeviceIdentityStore deviceIdentityStore,
  }) : _database = database,
       _authRepository = authRepository,
       _deviceIdentityStore = deviceIdentityStore;

  static const int schemaVersion = 1;
  static const int _flushBatchSize = 20;
  static const int _maxRetryDelaySeconds = 1800;

  final AppDatabase _database;
  final AuthRepository _authRepository;
  final DeviceIdentityStore _deviceIdentityStore;

  Stream<int> watchPendingCount({required String backendUserId}) {
    final now = DateTime.now().toUtc();
    final query = _database.select(_database.syncOutboxItems)
      ..where(
        (tbl) =>
            tbl.backendUserId.equals(backendUserId) &
            (tbl.nextRetryAt.isNull() |
                tbl.nextRetryAt.isSmallerOrEqualValue(now)),
      );
    return query.watch().map((rows) => rows.length);
  }

  Future<int> loadPendingCount({required String backendUserId}) async {
    final now = DateTime.now().toUtc();
    final countExpression = _database.syncOutboxItems.id.count();
    final row =
        await (_database.selectOnly(_database.syncOutboxItems)
              ..addColumns([countExpression])
              ..where(
                _database.syncOutboxItems.backendUserId.equals(backendUserId) &
                    (_database.syncOutboxItems.nextRetryAt.isNull() |
                        _database.syncOutboxItems.nextRetryAt
                            .isSmallerOrEqualValue(now)),
              ))
            .getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<void> enqueueDailyAttemptSaved({
    required String backendUserId,
    required int sessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    required String? wrongReasonTag,
  }) async {
    await _upsertEvent(
      backendUserId: backendUserId,
      logicalKey: 'daily:$sessionId:$questionId',
      eventType: SyncOutboxEventType.dailyAttemptSaved,
      payload: <String, Object?>{
        'sessionId': sessionId,
        'questionId': questionId,
        'selectedAnswer': selectedAnswer,
        'isCorrect': isCorrect,
        'wrongReasonTag': wrongReasonTag,
      },
    );
  }

  Future<void> enqueueVocabQuizCompleted({
    required String backendUserId,
    required String dayKey,
    required String track,
    required int totalCount,
    required int correctCount,
    required List<String> wrongVocabIds,
  }) async {
    await _upsertEvent(
      backendUserId: backendUserId,
      logicalKey: 'vocab:$dayKey:$track',
      eventType: SyncOutboxEventType.vocabQuizCompleted,
      payload: <String, Object?>{
        'dayKey': dayKey,
        'track': track,
        'totalCount': totalCount,
        'correctCount': correctCount,
        'wrongVocabIds': wrongVocabIds,
      },
    );
  }

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
    await _upsertEvent(
      backendUserId: backendUserId,
      logicalKey: 'mock:$mockSessionId:completed',
      eventType: SyncOutboxEventType.mockExamCompleted,
      payload: <String, Object?>{
        'mockSessionId': mockSessionId,
        'examType': examType,
        'periodKey': periodKey,
        'track': track,
        'plannedItems': plannedItems,
        'completedItems': completedItems,
        'listeningCorrectCount': listeningCorrectCount,
        'readingCorrectCount': readingCorrectCount,
        'wrongCount': wrongCount,
      },
    );
  }

  Future<SyncFlushResult> flushPending({required String backendUserId}) async {
    final pendingItems = await _loadReadyItems(
      backendUserId: backendUserId,
      limit: _flushBatchSize,
    );
    if (pendingItems.isEmpty) {
      return SyncFlushResult(
        attempted: 0,
        accepted: 0,
        duplicate: 0,
        invalid: 0,
        failed: 0,
        remaining: 0,
        lastErrorCode: null,
      );
    }

    try {
      final response = await _authRepository.authorizedPost(
        '/sync/events',
        body: <String, Object?>{
          'events': pendingItems.map(_toRequestBody).toList(growable: false),
        },
      );
      final body = response.bodyAsMap;
      final results = body['results'];
      if (results is! List<Object?> || results.length != pendingItems.length) {
        await _markBatchFailed(
          pendingItems,
          errorCode: 'sync_response_invalid',
        );
        final remaining = await loadPendingCount(backendUserId: backendUserId);
        return SyncFlushResult(
          attempted: pendingItems.length,
          accepted: 0,
          duplicate: 0,
          invalid: 0,
          failed: pendingItems.length,
          remaining: remaining,
          lastErrorCode: 'sync_response_invalid',
        );
      }

      var accepted = 0;
      var duplicate = 0;
      var invalid = 0;

      for (var index = 0; index < pendingItems.length; index++) {
        final rawResult = results[index];
        final detailCode = _readStringField(rawResult, 'detail_code');
        final status = _readStringField(rawResult, 'status');
        switch (status) {
          case 'accepted':
            accepted += 1;
            await _deleteById(pendingItems[index].id);
          case 'duplicate':
            duplicate += 1;
            await _deleteById(pendingItems[index].id);
          case 'invalid':
            invalid += 1;
            await _markFailed(
              pendingItems[index],
              errorCode: detailCode ?? 'sync_item_invalid',
            );
          default:
            invalid += 1;
            await _markFailed(
              pendingItems[index],
              errorCode: detailCode ?? 'sync_item_unknown_status',
            );
        }
      }

      final remaining = await loadPendingCount(backendUserId: backendUserId);
      return SyncFlushResult(
        attempted: pendingItems.length,
        accepted: accepted,
        duplicate: duplicate,
        invalid: invalid,
        failed: 0,
        remaining: remaining,
        lastErrorCode: invalid > 0 ? 'sync_item_invalid' : null,
      );
    } on AuthRepositoryException catch (error) {
      if (error.isUnauthorized) {
        rethrow;
      }
      await _markBatchFailed(pendingItems, errorCode: error.code);
      final remaining = await loadPendingCount(backendUserId: backendUserId);
      return SyncFlushResult(
        attempted: pendingItems.length,
        accepted: 0,
        duplicate: 0,
        invalid: 0,
        failed: pendingItems.length,
        remaining: remaining,
        lastErrorCode: error.code,
      );
    } catch (_) {
      await _markBatchFailed(pendingItems, errorCode: 'sync_request_failed');
      final remaining = await loadPendingCount(backendUserId: backendUserId);
      return SyncFlushResult(
        attempted: pendingItems.length,
        accepted: 0,
        duplicate: 0,
        invalid: 0,
        failed: pendingItems.length,
        remaining: remaining,
        lastErrorCode: 'sync_request_failed',
      );
    }
  }

  Future<void> _upsertEvent({
    required String backendUserId,
    required String logicalKey,
    required SyncOutboxEventType eventType,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now().toUtc();
    final deviceId = await _deviceIdentityStore.getOrCreateDeviceId();
    final idempotencyKey = buildSyncIdempotencyKey(
      backendUserId: backendUserId,
      eventType: eventType,
      logicalKey: logicalKey,
    );
    final payloadJson = jsonEncode(payload);

    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.syncOutboxItems)..where((tbl) {
                return tbl.backendUserId.equals(backendUserId) &
                    tbl.logicalKey.equals(logicalKey);
              }))
              .getSingleOrNull();

      if (existing == null) {
        await _database
            .into(_database.syncOutboxItems)
            .insert(
              SyncOutboxItemsCompanion.insert(
                backendUserId: backendUserId,
                logicalKey: logicalKey,
                eventType: eventType.apiValue,
                schemaVersion: schemaVersion,
                deviceId: deviceId,
                occurredAtClient: now,
                idempotencyKey: idempotencyKey,
                payloadJson: payloadJson,
                retryCount: const Value(0),
                nextRetryAt: const Value(null),
                lastErrorCode: const Value(null),
                updatedAt: Value(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.syncOutboxItems,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        SyncOutboxItemsCompanion(
          eventType: Value(eventType.apiValue),
          schemaVersion: const Value(schemaVersion),
          deviceId: Value(deviceId),
          occurredAtClient: Value(now),
          idempotencyKey: Value(idempotencyKey),
          payloadJson: Value(payloadJson),
          retryCount: const Value(0),
          nextRetryAt: const Value(null),
          lastErrorCode: const Value(null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<List<SyncOutboxEntry>> _loadReadyItems({
    required String backendUserId,
    required int limit,
  }) async {
    final now = DateTime.now().toUtc();
    final rows =
        await (_database.select(_database.syncOutboxItems)
              ..where(
                (tbl) =>
                    tbl.backendUserId.equals(backendUserId) &
                    (tbl.nextRetryAt.isNull() |
                        tbl.nextRetryAt.isSmallerOrEqualValue(now)),
              )
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.createdAt),
                (tbl) => OrderingTerm.asc(tbl.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(_toEntry).toList(growable: false);
  }

  SyncOutboxEntry _toEntry(SyncOutboxItem row) {
    return SyncOutboxEntry(
      id: row.id,
      backendUserId: row.backendUserId,
      logicalKey: row.logicalKey,
      eventType: _eventTypeFromApi(row.eventType),
      schemaVersion: row.schemaVersion,
      deviceId: row.deviceId,
      occurredAtClient: row.occurredAtClient,
      idempotencyKey: row.idempotencyKey,
      payloadJson: row.payloadJson,
      retryCount: row.retryCount,
      nextRetryAt: row.nextRetryAt,
      lastErrorCode: row.lastErrorCode,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Map<String, Object?> _toRequestBody(SyncOutboxEntry entry) {
    return <String, Object?>{
      'event_type': entry.eventType.apiValue,
      'schema_version': entry.schemaVersion,
      'device_id': entry.deviceId,
      'occurred_at_client': entry.occurredAtClient.toIso8601String(),
      'idempotency_key': entry.idempotencyKey,
      'payload': jsonDecode(entry.payloadJson),
    };
  }

  SyncOutboxEventType _eventTypeFromApi(String value) {
    switch (value) {
      case 'DAILY_ATTEMPT_SAVED':
        return SyncOutboxEventType.dailyAttemptSaved;
      case 'VOCAB_QUIZ_COMPLETED':
        return SyncOutboxEventType.vocabQuizCompleted;
      case 'MOCK_EXAM_COMPLETED':
        return SyncOutboxEventType.mockExamCompleted;
      default:
        throw FormatException('Unsupported sync event type: "$value"');
    }
  }

  Future<void> _deleteById(int id) {
    return (_database.delete(
      _database.syncOutboxItems,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<void> _markBatchFailed(
    List<SyncOutboxEntry> entries, {
    required String errorCode,
  }) async {
    for (final entry in entries) {
      await _markFailed(entry, errorCode: errorCode);
    }
  }

  Future<void> _markFailed(
    SyncOutboxEntry entry, {
    required String errorCode,
  }) async {
    final nextRetryCount = entry.retryCount + 1;
    final delaySeconds = min(
      30 * (1 << (nextRetryCount.clamp(0, 5))),
      _maxRetryDelaySeconds,
    );
    final nextRetryAt = DateTime.now().toUtc().add(
      Duration(seconds: delaySeconds),
    );
    await (_database.update(
      _database.syncOutboxItems,
    )..where((tbl) => tbl.id.equals(entry.id))).write(
      SyncOutboxItemsCompanion(
        retryCount: Value(nextRetryCount),
        nextRetryAt: Value(nextRetryAt),
        lastErrorCode: Value(errorCode),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  String? _readStringField(Object? raw, String key) {
    if (raw is Map<Object?, Object?>) {
      final value = raw[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    if (raw is Map<String, Object?>) {
      final value = raw[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
