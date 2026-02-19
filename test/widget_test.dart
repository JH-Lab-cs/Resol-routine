import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/app/app.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/content_pack/application/content_pack_bootstrap.dart';
import 'package:resol_routine/features/today/application/today_quiz_providers.dart';
import 'package:resol_routine/features/today/application/today_session_providers.dart';
import 'package:resol_routine/features/today/data/attempt_payload.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';

void main() {
  testWidgets('opens quiz question from home CTA', (WidgetTester tester) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);

    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 지훈! 👋'));

    expect(find.text('오늘도 화이팅, 지훈! 👋'), findsOneWidget);
    expect(find.text('오늘 루틴 시작하기'), findsOneWidget);

    await tester.tap(find.text('오늘 루틴 시작하기'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('시작하기'));

    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('문제 1 / 6'));

    expect(find.text('문제 1 / 6'), findsOneWidget);
  });
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Did not find expected widget after ${maxPumps * 50}ms.');
}

class _FakeTodaySessionRepository extends TodaySessionRepository {
  _FakeTodaySessionRepository(AppDatabase database) : super(database: database);

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) async {
    return DailySessionBundle(
      sessionId: 1,
      dayKey: '20260219',
      track: track,
      plannedItems: 6,
      completedItems: 0,
      items: const [
        DailySessionItemBundle(
          orderIndex: 0,
          questionId: 'L-001',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 1,
          questionId: 'L-002',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 2,
          questionId: 'L-003',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 3,
          questionId: 'R-001',
          skill: 'READING',
        ),
        DailySessionItemBundle(
          orderIndex: 4,
          questionId: 'R-002',
          skill: 'READING',
        ),
        DailySessionItemBundle(
          orderIndex: 5,
          questionId: 'R-003',
          skill: 'READING',
        ),
      ],
    );
  }
}

class _FakeTodayQuizRepository extends TodayQuizRepository {
  _FakeTodayQuizRepository(AppDatabase database) : super(database: database);

  final List<QuizQuestionDetail> _questions = <QuizQuestionDetail>[
    QuizQuestionDetail(
      orderIndex: 0,
      questionId: 'L-001',
      skill: 'LISTENING',
      typeTag: 'L1',
      track: 'M3',
      prompt: 'What does the student order?',
      options: const OptionMap(
        a: 'Tea',
        b: 'Coffee',
        c: 'Milk',
        d: 'Juice',
        e: 'Water',
      ),
      answerKey: 'B',
      whyCorrectKo: '대화에서 coffee라고 말합니다.',
      whyWrongKo: const OptionMap(
        a: '주문 음료가 아닙니다.',
        b: '정답입니다.',
        c: '언급되지 않았습니다.',
        d: '언급되지 않았습니다.',
        e: '언급되지 않았습니다.',
      ),
      evidenceSentenceIds: <String>['ls_1'],
      sourceLines: <SourceLine>[
        SourceLine(
          sentenceIds: <String>['ls_1'],
          text: 'I would like a coffee, please.',
          index: 0,
          speaker: 'S1',
        ),
      ],
    ),
    ..._fillerQuestions,
  ];

  @override
  Future<List<QuizQuestionDetail>> loadSessionQuestions(int sessionId) async {
    return _questions;
  }

  @override
  Future<Map<String, AttemptPayload>> loadSessionAttempts(int sessionId) async {
    return <String, AttemptPayload>{};
  }

  @override
  Future<int> findFirstUnansweredOrderIndex({required int sessionId}) async {
    return 0;
  }

  @override
  Future<SessionProgress> loadSessionProgress(int sessionId) async {
    return const SessionProgress(
      completed: 0,
      listeningCompleted: 0,
      readingCompleted: 0,
    );
  }
}

final List<QuizQuestionDetail> _fillerQuestions =
    List<QuizQuestionDetail>.generate(
      5,
      (index) => QuizQuestionDetail(
        orderIndex: index + 1,
        questionId: 'Q-${index + 2}',
        skill: index < 2 ? 'LISTENING' : 'READING',
        typeTag: index < 2 ? 'L2' : 'R2',
        track: 'M3',
        prompt: 'Filler question ${index + 2}',
        options: const OptionMap(a: 'A', b: 'B', c: 'C', d: 'D', e: 'E'),
        answerKey: 'A',
        whyCorrectKo: '정답 해설',
        whyWrongKo: const OptionMap(
          a: '정답',
          b: '오답',
          c: '오답',
          d: '오답',
          e: '오답',
        ),
        evidenceSentenceIds: const <String>['s1'],
        sourceLines: <SourceLine>[
          SourceLine(
            sentenceIds: const <String>['s1'],
            text: 'Sample source line',
            index: 0,
            speaker: index < 2 ? 'S1' : null,
          ),
        ],
      ),
    );
