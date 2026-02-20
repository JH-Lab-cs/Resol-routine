import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/components/app_scaffold.dart';
import '../../home/presentation/home_screen.dart';
import '../../my/presentation/my_screen.dart';
import '../../today/application/today_session_providers.dart';
import '../../today/presentation/quiz_flow_screen.dart';
import '../../vocab/presentation/today_vocab_quiz_screen.dart';
import '../../vocab/presentation/vocab_screen.dart';
import '../../wrong_notes/presentation/wrong_notes_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _currentIndex = 0;
  static const List<String> _tabTitles = <String>['홈', '단어장', '오답노트', '설정'];

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(
        onOpenQuiz: _openQuiz,
        onOpenVocab: () => _selectTab(1),
        onOpenTodayVocabQuiz: _openTodayVocabQuiz,
        onOpenWrongNotes: () => _selectTab(2),
        onOpenMy: () => _selectTab(3),
      ),
      const VocabScreen(),
      const WrongNotesScreen(),
      const MyScreen(),
    ];

    return AppScaffold(
      appBar: AppBar(title: Text(_tabTitles[_currentIndex])),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _selectTab,
        destinations: const [
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
        ],
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
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
            _selectTab(2);
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
}
