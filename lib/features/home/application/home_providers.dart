import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/application/user_settings_providers.dart' as settings;
import '../../today/application/today_quiz_providers.dart';
import '../../today/application/today_session_providers.dart';
import '../../today/data/today_quiz_repository.dart';
import '../../today/data/today_session_repository.dart';

final displayNameProvider = settings.displayNameProvider;

class HomeRoutineSummary {
  const HomeRoutineSummary({required this.session, required this.progress});

  final DailySessionBundle session;
  final SessionProgress progress;
}

final homeRoutineSummaryProvider =
    FutureProvider.family<HomeRoutineSummary, String>((
      Ref ref,
      String track,
    ) async {
      final session = await ref.watch(todaySessionProvider(track).future);
      final quizRepository = ref.watch(todayQuizRepositoryProvider);
      final progress = await quizRepository.loadSessionProgress(
        session.sessionId,
      );
      return HomeRoutineSummary(session: session, progress: progress);
    });
