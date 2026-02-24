import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/time/day_key.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/report_export_repository.dart';
import 'package:resol_routine/features/report/presentation/student_report_screen.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  testWidgets('shows loading skeleton first and handles text scale safely', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final reportExportRepository = ReportExportRepository(
      database: database,
      appVersionLoader: () async => '1.0.0+1',
    );
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          reportExportRepositoryProvider.overrideWithValue(
            reportExportRepository,
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: const MaterialApp(home: StudentReportScreen(track: 'M3')),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('student-report-loading-skeleton')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows vocab quiz summary on student report when available', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    late ReportExportRepository reportExportRepository;
    late String firstLemma;
    late String secondLemma;
    late String bookmarkedLemma;
    await tester.runAsync(() async {
      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      final sessionRepository = TodaySessionRepository(database: database);
      final quizRepository = TodayQuizRepository(database: database);
      final vocabQuizResultsRepository = VocabQuizResultsRepository(
        database: database,
      );
      final mockExamSessionRepository = MockExamSessionRepository(
        database: database,
      );
      final mockExamAttemptRepository = MockExamAttemptRepository(
        database: database,
      );
      reportExportRepository = ReportExportRepository(
        database: database,
        appVersionLoader: () async => '1.0.0+1',
      );
      final vocabRows =
          await (database.select(database.vocabMaster)
                ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)])
                ..limit(2))
              .get();
      expect(vocabRows.length, greaterThanOrEqualTo(2));
      firstLemma = vocabRows[0].lemma;
      secondLemma = vocabRows[1].lemma;
      bookmarkedLemma = 'bookmark_probe_lemma';
      const bookmarkedVocabId = 'aaa_bookmark_probe';
      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: bookmarkedVocabId,
              lemma: bookmarkedLemma,
              meaning: 'bookmark probe meaning',
            ),
          );

      final now = DateTime.now();
      final dayKey = formatDayKey(now);
      final session = await sessionRepository.getOrCreateSession(
        track: 'M3',
        nowLocal: now,
      );
      await quizRepository.saveAttemptIdempotent(
        sessionId: session.sessionId,
        questionId: session.items.first.questionId,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      await vocabQuizResultsRepository.upsertDailyResult(
        dayKey: dayKey,
        track: 'M3',
        totalCount: 20,
        correctCount: 18,
        wrongVocabIds: <String>[vocabRows[0].id, vocabRows[1].id],
      );

      const testPlan = MockExamQuestionPlan(listeningCount: 3, readingCount: 3);
      final weeklySession = await mockExamSessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: testPlan,
        nowLocal: DateTime(2026, 2, 21, 18, 0),
      );
      await _completeMockSession(
        repository: mockExamAttemptRepository,
        session: weeklySession,
        listeningCorrectTarget: 2,
        readingCorrectTarget: 2,
      );

      await database
          .into(database.vocabUser)
          .insert(
            VocabUserCompanion.insert(
              vocabId: bookmarkedVocabId,
              isBookmarked: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          reportExportRepositoryProvider.overrideWithValue(
            reportExportRepository,
          ),
        ],
        child: const MaterialApp(home: StudentReportScreen(track: 'M3')),
      ),
    );

    await _pumpUntilVisible(tester, find.textContaining('단어시험 18/20 · 90%'));
    await _pumpUntilVisible(tester, find.text(firstLemma));
    expect(find.textContaining('단어시험 18/20 · 90%'), findsAtLeastNWidgets(1));
    expect(find.text(firstLemma), findsOneWidget);
    expect(find.text(secondLemma), findsOneWidget);
    expect(find.text('북마크 단어장'), findsOneWidget);
    expect(find.text('모의고사 요약'), findsOneWidget);
    expect(find.text(bookmarkedLemma), findsNothing);

    await tester.tap(find.text('북마크 단어장'));
    await tester.pumpAndSettle();

    expect(find.text(bookmarkedLemma), findsOneWidget);

    await tester.ensureVisible(find.text('모의고사 요약'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모의고사 요약'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026W08'), findsOneWidget);
    expect(find.textContaining('정답 4/20 · 20%'), findsOneWidget);
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

Future<void> _completeMockSession({
  required MockExamAttemptRepository repository,
  required MockExamSessionBundle session,
  required int listeningCorrectTarget,
  required int readingCorrectTarget,
}) async {
  var listeningSeen = 0;
  var readingSeen = 0;
  for (final item in session.items) {
    late final bool isCorrect;
    if (item.skill == Skill.listening) {
      listeningSeen += 1;
      isCorrect = listeningSeen <= listeningCorrectTarget;
    } else {
      readingSeen += 1;
      isCorrect = readingSeen <= readingCorrectTarget;
    }
    await repository.saveAttemptIdempotent(
      mockSessionId: session.sessionId,
      questionId: item.questionId,
      selectedAnswer: 'A',
      isCorrect: isCorrect,
      wrongReasonTag: isCorrect ? null : WrongReasonTag.vocab,
    );
  }
}
