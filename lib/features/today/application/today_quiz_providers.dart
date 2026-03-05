import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/today_quiz_repository.dart';

final todayQuizRepositoryProvider = Provider<TodayQuizRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return TodayQuizRepository(database: database);
});
