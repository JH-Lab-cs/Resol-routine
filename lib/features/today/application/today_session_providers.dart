import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../settings/application/user_settings_providers.dart' as settings;
import '../data/today_session_repository.dart';

final selectedTrackProvider = settings.selectedTrackProvider;

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
