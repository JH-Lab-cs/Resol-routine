import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/today/application/today_session_providers.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/today/presentation/quiz_flow_screen.dart';

void main() {
  group('QuizFlowScreen daily section order', () {
    late AppDatabase database;
    late TodayQuizRepository quizRepository;
    late _FixedNowSessionRepository sessionRepository;
    final fixedNow = DateTime(2026, 3, 8, 9, 0);

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      quizRepository = TodayQuizRepository(database: database);
      sessionRepository = _FixedNowSessionRepository(database, fixedNow);

      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('listening-first start completes daily routine', (
      WidgetTester tester,
    ) async {
      await _pumpQuizFlow(
        tester,
        database: database,
        sessionRepository: sessionRepository,
      );

      expect(
        find.byKey(
          const ValueKey<String>('daily-section-order-listening-first'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('daily-section-order-reading-first')),
        findsOneWidget,
      );

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      final session = await sessionRepository.getOrCreateSession(
        track: 'M3',
        nowLocal: fixedNow,
      );
      final questions = await quizRepository.loadSessionQuestions(
        session.sessionId,
      );

      expect(session.sectionOrder, DailySectionOrder.listeningFirst);
      expect(questions.first.skill, Skill.listening);
      expect(find.text('문제 1 / 6'), findsOneWidget);
      expect(find.text('듣기'), findsAtLeastNWidgets(1));

      await _saveCorrectAttempts(
        quizRepository,
        sessionId: session.sessionId,
        questions: questions,
        startIndex: 0,
      );
      await _pumpQuizFlow(
        tester,
        database: database,
        sessionRepository: sessionRepository,
      );

      expect(find.text('오늘 루틴 완료 🎉'), findsOneWidget);
      final report = await quizRepository.loadSessionCompletionReport(
        session.sessionId,
      );
      expect(report.listeningCorrectCount, 3);
      expect(report.readingCorrectCount, 3);
      expect(report.wrongCount, 0);
    });

    testWidgets('reading-first selection resumes in preserved order', (
      WidgetTester tester,
    ) async {
      await _pumpQuizFlow(
        tester,
        database: database,
        sessionRepository: sessionRepository,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('daily-section-order-reading-first')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      final session = await sessionRepository.getOrCreateSession(
        track: 'M3',
        nowLocal: fixedNow,
      );
      final questions = await quizRepository.loadSessionQuestions(
        session.sessionId,
      );

      expect(session.sectionOrder, DailySectionOrder.readingFirst);
      expect(questions.first.skill, Skill.reading);
      expect(find.text('문제 1 / 6'), findsOneWidget);
      expect(find.text('독해'), findsAtLeastNWidgets(1));

      await _saveCorrectAttempts(
        quizRepository,
        sessionId: session.sessionId,
        questions: questions,
        startIndex: 0,
        endExclusive: 1,
      );

      await _pumpQuizFlow(
        tester,
        database: database,
        sessionRepository: sessionRepository,
      );

      expect(find.text('이어하기'), findsOneWidget);
      expect(find.text('현재 순서: 독해 먼저'), findsOneWidget);

      await tester.tap(find.text('이어하기'));
      await tester.pumpAndSettle();

      expect(find.text('문제 2 / 6'), findsOneWidget);
      expect(find.text('독해'), findsAtLeastNWidgets(1));

      await _saveCorrectAttempts(
        quizRepository,
        sessionId: session.sessionId,
        questions: questions,
        startIndex: 1,
      );
      await _pumpQuizFlow(
        tester,
        database: database,
        sessionRepository: sessionRepository,
      );

      expect(find.text('오늘 루틴 완료 🎉'), findsOneWidget);
      final report = await quizRepository.loadSessionCompletionReport(
        session.sessionId,
      );
      expect(report.listeningCorrectCount, 3);
      expect(report.readingCorrectCount, 3);
      expect(report.wrongCount, 0);
    });
  });
}

Future<void> _pumpQuizFlow(
  WidgetTester tester, {
  required AppDatabase database,
  required TodaySessionRepository sessionRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        todaySessionRepositoryProvider.overrideWithValue(sessionRepository),
      ],
      child: MaterialApp(
        home: QuizFlowScreen(key: UniqueKey(), track: 'M3'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveCorrectAttempts(
  TodayQuizRepository quizRepository, {
  required int sessionId,
  required List<QuizQuestionDetail> questions,
  required int startIndex,
  int? endExclusive,
}) async {
  final upperBound = endExclusive ?? questions.length;
  for (var index = startIndex; index < upperBound; index++) {
    final question = questions[index];
    await quizRepository.saveAttemptIdempotent(
      sessionId: sessionId,
      questionId: question.questionId,
      selectedAnswer: question.answerKey,
      isCorrect: true,
    );
  }
}

class _FixedNowSessionRepository extends TodaySessionRepository {
  _FixedNowSessionRepository(AppDatabase database, this.fixedNow)
    : super(database: database);

  final DateTime fixedNow;

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) {
    return super.getOrCreateSession(track: track, nowLocal: fixedNow);
  }
}
