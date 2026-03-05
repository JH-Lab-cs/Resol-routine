import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/my_stats_repository.dart';

final myStatsRepositoryProvider = Provider<MyStatsRepository>((Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return MyStatsRepository(database: database);
});

final myStatsProvider = FutureProvider.family<MyStatsSnapshot, String>((
  Ref ref,
  String track,
) {
  final repository = ref.watch(myStatsRepositoryProvider);
  return repository.load(track: track);
});
