import '../../../core/security/sha256_hash.dart';

enum SyncOutboxEventType {
  dailyAttemptSaved,
  vocabQuizCompleted,
  mockExamCompleted,
}

extension SyncOutboxEventTypeApiValue on SyncOutboxEventType {
  String get apiValue {
    switch (this) {
      case SyncOutboxEventType.dailyAttemptSaved:
        return 'DAILY_ATTEMPT_SAVED';
      case SyncOutboxEventType.vocabQuizCompleted:
        return 'VOCAB_QUIZ_COMPLETED';
      case SyncOutboxEventType.mockExamCompleted:
        return 'MOCK_EXAM_COMPLETED';
    }
  }
}

class SyncOutboxEntry {
  const SyncOutboxEntry({
    required this.id,
    required this.backendUserId,
    required this.logicalKey,
    required this.eventType,
    required this.schemaVersion,
    required this.deviceId,
    required this.occurredAtClient,
    required this.idempotencyKey,
    required this.payloadJson,
    required this.retryCount,
    required this.nextRetryAt,
    required this.lastErrorCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String backendUserId;
  final String logicalKey;
  final SyncOutboxEventType eventType;
  final int schemaVersion;
  final String deviceId;
  final DateTime occurredAtClient;
  final String idempotencyKey;
  final String payloadJson;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SyncFlushResult {
  const SyncFlushResult({
    required this.attempted,
    required this.accepted,
    required this.duplicate,
    required this.invalid,
    required this.failed,
    required this.remaining,
    required this.lastErrorCode,
  });

  final int attempted;
  final int accepted;
  final int duplicate;
  final int invalid;
  final int failed;
  final int remaining;
  final String? lastErrorCode;

  bool get hasWork => attempted > 0;
}

String buildSyncIdempotencyKey({
  required String backendUserId,
  required SyncOutboxEventType eventType,
  required String logicalKey,
}) {
  return computeSha256Hex(
    '$backendUserId|${eventType.apiValue}|$logicalKey',
  );
}
