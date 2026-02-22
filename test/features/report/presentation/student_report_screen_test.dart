import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/time/day_key.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/report_export_repository.dart';
import 'package:resol_routine/features/report/presentation/student_report_screen.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  testWidgets('shows vocab quiz summary on student report when available', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    late ReportExportRepository reportExportRepository;
    late String firstLemma;
    late String secondLemma;
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

    await _pumpUntilVisible(tester, find.textContaining('단어시험 18/20'));
    await _pumpUntilVisible(tester, find.text(firstLemma));
    expect(find.textContaining('단어시험 18/20'), findsAtLeastNWidgets(1));
    expect(find.text(firstLemma), findsOneWidget);
    expect(find.text(secondLemma), findsOneWidget);
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
