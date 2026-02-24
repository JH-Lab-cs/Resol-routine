import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
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
