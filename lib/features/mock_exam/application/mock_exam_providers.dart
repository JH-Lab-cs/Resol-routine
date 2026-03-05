import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/domain_enums.dart';
import '../data/mock_exam_attempt_repository.dart';
import '../data/mock_exam_session_repository.dart';

final mockExamSessionRepositoryProvider = Provider<MockExamSessionRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return MockExamSessionRepository(database: database);
});

final mockExamAttemptRepositoryProvider = Provider<MockExamAttemptRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return MockExamAttemptRepository(database: database);
});

final mockExamResultSummaryProvider =
    FutureProvider.family<MockExamResultSummary, int>((Ref ref, int sessionId) {
      final repository = ref.watch(mockExamAttemptRepositoryProvider);
      return repository.loadResultSummary(sessionId: sessionId);
    });

final mockExamReviewItemsProvider =
    FutureProvider.family<List<MockReviewItem>, int>((Ref ref, int sessionId) {
      final repository = ref.watch(mockExamAttemptRepositoryProvider);
      return repository.listReviewItems(sessionId: sessionId);
    });

final mockExamWrongItemsProvider =
    FutureProvider.family<List<MockWrongItem>, int>((Ref ref, int sessionId) {
      final repository = ref.watch(mockExamAttemptRepositoryProvider);
      return repository.listWrongItems(sessionId: sessionId);
    });

class MockExamHistoryQuery {
  const MockExamHistoryQuery({
    required this.type,
    required this.track,
    this.limit = 20,
  });

  final MockExamType type;
  final String track;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is MockExamHistoryQuery &&
        other.type == type &&
        other.track == track &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(type, track, limit);
}

class MockExamCurrentSummaryQuery {
  const MockExamCurrentSummaryQuery({required this.type, required this.track});

  final MockExamType type;
  final String track;

  @override
  bool operator ==(Object other) {
    return other is MockExamCurrentSummaryQuery &&
        other.type == type &&
        other.track == track;
  }

  @override
  int get hashCode => Object.hash(type, track);
}

final mockExamRecentSessionsProvider =
    FutureProvider.family<List<MockExamSessionSummary>, MockExamHistoryQuery>((
      Ref ref,
      MockExamHistoryQuery query,
    ) {
      final repository = ref.watch(mockExamSessionRepositoryProvider);
      return repository.listRecent(
        type: query.type,
        track: query.track,
        limit: query.limit,
      );
    });

final mockExamCurrentSummaryProvider =
    FutureProvider.family<MockExamSessionSummary?, MockExamCurrentSummaryQuery>(
      (Ref ref, MockExamCurrentSummaryQuery query) {
        final repository = ref.watch(mockExamSessionRepositoryProvider);
        return repository.findCurrentPeriodSummary(
          type: query.type,
          track: query.track,
        );
      },
    );
