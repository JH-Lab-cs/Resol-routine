import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/vocab_repository.dart';

final vocabRepositoryProvider = Provider<VocabRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return VocabRepository(database: database);
});
