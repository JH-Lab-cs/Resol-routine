import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/report/data/report_export_repository.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  group('ReportExportRepository', () {
    late AppDatabase database;
    late TodaySessionRepository sessionRepository;
    late TodayQuizRepository quizRepository;
    late ReportExportRepository reportRepository;
    late VocabQuizResultsRepository vocabQuizResultsRepository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      sessionRepository = TodaySessionRepository(database: database);
      quizRepository = TodayQuizRepository(database: database);
      reportRepository = ReportExportRepository(
        database: database,
        appVersionLoader: () async => '9.9.9+9',
      );
      vocabQuizResultsRepository = VocabQuizResultsRepository(
        database: database,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'builds cumulative report for track and strips copyrighted text',
      () async {
        final firstDay = await sessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 20, 9, 0),
        );
        final secondDay = await sessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 21, 9, 0),
        );

        await quizRepository.saveAttemptIdempotent(
          sessionId: firstDay.sessionId,
          questionId: firstDay.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: firstDay.sessionId,
          questionId: firstDay.items[1].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: secondDay.sessionId,
          questionId: secondDay.items[0].questionId,
          selectedAnswer: 'C',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.evidence,
        );

        final exportPayload = await reportRepository.buildExportPayload(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 21, 10, 0),
        );

        expect(exportPayload.fileName, 'resolroutine_report_20260221_M3.json');
        expect(exportPayload.report.schemaVersion, 2);
        expect(exportPayload.report.appVersion, '9.9.9+9');
        expect(exportPayload.report.days, hasLength(2));
        expect(exportPayload.report.days.first.dayKey, '20260221');
        expect(exportPayload.report.days.first.solvedCount, 1);
        expect(exportPayload.report.days.first.wrongCount, 1);
        expect(
          exportPayload.report.days.first.wrongReasonCounts[WrongReasonTag
              .evidence],
          1,
        );

        final questionRow = await (database.select(
          database.questions,
        )..limit(1)).getSingle();
        final explanationRow = await (database.select(
          database.explanations,
        )..where((tbl) => tbl.questionId.equals(questionRow.id))).getSingle();

        expect(exportPayload.jsonPayload.contains(questionRow.prompt), isFalse);
        expect(
          exportPayload.jsonPayload.contains(questionRow.optionsJson.a),
          isFalse,
        );
        expect(
          exportPayload.jsonPayload.contains(explanationRow.whyCorrectKo),
          isFalse,
        );
      },
    );

    test(
      'returns empty days when no sessions exist for selected track',
      () async {
        final report = await reportRepository.buildCumulativeReport(
          track: 'H3',
          nowLocal: DateTime(2026, 2, 21, 12, 0),
        );

        expect(report.days, isEmpty);
        expect(report.schemaVersion, 2);
      },
    );

    test(
      'includes vocab-only day entries when no daily session exists',
      () async {
        final vocabRows =
            await (database.select(database.vocabMaster)
                  ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)])
                  ..limit(3))
                .get();
        expect(vocabRows.length, greaterThanOrEqualTo(3));
        final wrongIds = <String>[
          vocabRows[0].id,
          vocabRows[1].id,
          vocabRows[2].id,
        ];
        final expectedWrongIds = <String>[...wrongIds]..sort();

        await vocabQuizResultsRepository.upsertDailyResult(
          dayKey: '20260222',
          track: 'H3',
          totalCount: 20,
          correctCount: 17,
          wrongVocabIds: wrongIds,
        );

        final report = await reportRepository.buildCumulativeReport(
          track: 'H3',
          nowLocal: DateTime(2026, 2, 22, 20, 0),
        );

        expect(report.days, hasLength(1));
        final day = report.days.first;
        expect(day.dayKey, '20260222');
        expect(day.track, Track.h3);
        expect(day.solvedCount, 0);
        expect(day.wrongCount, 0);
        expect(day.questions, isEmpty);
        expect(day.vocabQuiz, isNotNull);
        expect(day.vocabQuiz!.totalCount, 20);
        expect(day.vocabQuiz!.correctCount, 17);
        expect(day.vocabQuiz!.wrongVocabIds, expectedWrongIds);
      },
    );
  });
}
