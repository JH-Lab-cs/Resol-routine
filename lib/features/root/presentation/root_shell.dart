import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../dev/presentation/dev_reports_screen.dart';
import '../../content_sync/application/content_sync_providers.dart';
import '../../sync/application/sync_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../../my/presentation/my_screen.dart';
import '../../mock_exam/presentation/monthly_mock_flow_screen.dart';
import '../../mock_exam/presentation/weekly_mock_flow_screen.dart';
import '../../parent/presentation/parent_ui_helpers.dart';
import '../../settings/application/user_settings_providers.dart' as settings;
import '../../today/application/today_session_providers.dart';
import '../../today/presentation/quiz_flow_screen.dart';
import '../../vocab/presentation/today_vocab_quiz_screen.dart';
import '../../vocab/presentation/vocab_screen.dart';
import '../../wrong_notes/presentation/wrong_notes_screen.dart';
import '../../wrong_notes/presentation/wrong_review_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String? _lastAutoSyncedTrack;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    _triggerBackgroundSyncs();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(settings.selectedTrackProvider, (previous, next) {
      if (previous == next || !mounted) {
        return;
      }
      _lastAutoSyncedTrack = next;
      _triggerBackgroundSyncs(trackOverride: next);
    });
    final settingsAsync = ref.watch(settings.userSettingsProvider);

    return settingsAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('홈')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('홈')),
        body: Center(child: Text('설정을 불러오지 못했습니다.\n$error')),
      ),
      data: (settings) {
        if (_lastAutoSyncedTrack != settings.track) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _lastAutoSyncedTrack = settings.track;
            _triggerBackgroundSyncs(trackOverride: settings.track);
          });
        }
        final isParent = settings.role == 'PARENT';
        final tabs = _buildTabs(isParent);
        final destinations = _buildDestinations(isParent);
        final lastIndex = tabs.length - 1;
        final safeIndex = _currentIndex > lastIndex ? lastIndex : _currentIndex;

        if (safeIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentIndex = safeIndex;
            });
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Resol routine'),
            actions: [
              Semantics(
                label: '알림함',
                button: true,
                child: IconButton(
                  tooltip: '알림함',
                  onPressed: () =>
                      showNotificationInbox(context, ref, isParent: isParent),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ],
          ),
          body: IndexedStack(index: safeIndex, children: tabs),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectTab,
            destinations: destinations,
          ),
        );
      },
    );
  }

  List<Widget> _buildTabs(bool isParent) {
    if (isParent) {
      return <Widget>[
        HomeScreen(
          onOpenQuiz: _openQuiz,
          onOpenWeeklyMockExam: _openWeeklyMockExam,
          onOpenMonthlyMockExam: _openMonthlyMockExam,
          onOpenVocab: () {},
          onOpenTodayVocabQuiz: _openTodayVocabQuiz,
          onOpenWrongNotes: () {},
          onOpenWrongReview: () {},
          onOpenMy: () => _selectTab(1),
          onOpenDevReports: _openDevReports,
        ),
        const MyScreen(),
      ];
    }

    return <Widget>[
      HomeScreen(
        onOpenQuiz: _openQuiz,
        onOpenWeeklyMockExam: _openWeeklyMockExam,
        onOpenMonthlyMockExam: _openMonthlyMockExam,
        onOpenVocab: () => _selectTab(1),
        onOpenTodayVocabQuiz: _openTodayVocabQuiz,
        onOpenWrongNotes: () => _selectTab(2),
        onOpenWrongReview: _openWrongReview,
        onOpenMy: () => _selectTab(3),
      ),
      const VocabScreen(),
      const WrongNotesScreen(),
      const MyScreen(),
    ];
  }

  List<NavigationDestination> _buildDestinations(bool isParent) {
    if (isParent) {
      return const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: '홈',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: '마이',
        ),
      ];
    }

    return const <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: '홈',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded),
        label: '단어장',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_late_outlined),
        selectedIcon: Icon(Icons.assignment_late_rounded),
        label: '오답노트',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: '마이',
      ),
    ];
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _triggerBackgroundSyncs({String? trackOverride}) {
    unawaited(ref.read(syncFlushControllerProvider.notifier).flushNow());
    final String track =
        trackOverride ?? ref.read(settings.selectedTrackProvider);
    unawaited(
      ref.read(publishedContentSyncControllerProvider.notifier).syncTrack(
            track: track,
          ),
    );
  }

  void _openQuiz() {
    final track = ref.read(selectedTrackProvider);
    Navigator.of(context)
        .push<QuizFlowExitAction>(
          MaterialPageRoute<QuizFlowExitAction>(
            builder: (_) => QuizFlowScreen(track: track),
          ),
        )
        .then((action) {
          if (!mounted || action == null) {
            return;
          }

          if (action == QuizFlowExitAction.wrongNotes) {
            _openWrongNotesTabIfAvailable();
            return;
          }

          _selectTab(0);
        });
  }

  void _openTodayVocabQuiz() {
    Navigator.of(context)
        .push<VocabQuizExitAction>(
          MaterialPageRoute<VocabQuizExitAction>(
            builder: (_) => const TodayVocabQuizScreen(),
          ),
        )
        .then((action) {
          if (!mounted || action == null) {
            return;
          }

          if (action == VocabQuizExitAction.vocab) {
            _selectTab(1);
            return;
          }

          _selectTab(0);
        });
  }

  void _openWeeklyMockExam() {
    final track = ref.read(selectedTrackProvider);
    Navigator.of(context)
        .push<MockExamFlowExitAction>(
          MaterialPageRoute<MockExamFlowExitAction>(
            builder: (_) => WeeklyMockFlowScreen(track: track),
          ),
        )
        .then((action) {
          if (!mounted || action == null) {
            return;
          }

          if (action == MockExamFlowExitAction.wrongNotes) {
            _openWrongNotesTabIfAvailable();
            return;
          }

          _selectTab(0);
        });
  }

  void _openMonthlyMockExam() {
    final track = ref.read(selectedTrackProvider);
    Navigator.of(context)
        .push<MockExamFlowExitAction>(
          MaterialPageRoute<MockExamFlowExitAction>(
            builder: (_) => MonthlyMockFlowScreen(track: track),
          ),
        )
        .then((action) {
          if (!mounted || action == null) {
            return;
          }

          if (action == MockExamFlowExitAction.wrongNotes) {
            _openWrongNotesTabIfAvailable();
            return;
          }

          _selectTab(0);
        });
  }

  void _openWrongNotesTabIfAvailable() {
    final role = ref.read(settings.userSettingsProvider).valueOrNull?.role;
    if (role == 'PARENT') {
      _selectTab(0);
      return;
    }
    _selectTab(2);
  }

  void _openWrongReview() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const WrongReviewScreen()),
    );
  }

  void _openDevReports() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DevReportsScreen()),
    );
  }
}
