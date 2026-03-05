import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/vocab_quiz_results_repository.dart';
import '../data/vocab_repository.dart';

final vocabRepositoryProvider = Provider<VocabRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return VocabRepository(database: database);
});

final vocabQuizResultsRepositoryProvider = Provider<VocabQuizResultsRepository>(
  (Ref ref) {
    final database = ref.watch(appDatabaseProvider);
    return VocabQuizResultsRepository(database: database);
  },
);
