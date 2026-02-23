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
