import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/today_session_repository.dart';

final selectedTrackProvider = StateProvider<String>((Ref ref) => 'M3');

final todaySessionRepositoryProvider = Provider<TodaySessionRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return TodaySessionRepository(database: database);
});

final todaySessionProvider = FutureProvider.family<DailySessionBundle, String>((
  Ref ref,
  String track,
) async {
  final repository = ref.watch(todaySessionRepositoryProvider);
  return repository.getOrCreateSession(track: track);
});
