import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
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
    late MockExamSessionRepository mockExamSessionRepository;
    late MockExamAttemptRepository mockExamAttemptRepository;

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
      mockExamSessionRepository = MockExamSessionRepository(database: database);
      mockExamAttemptRepository = MockExamAttemptRepository(database: database);
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
        expect(exportPayload.report.schemaVersion, 5);
        expect(exportPayload.report.appVersion, '9.9.9+9');
        expect(exportPayload.report.days, hasLength(2));
        expect(exportPayload.report.mockExams, isNotNull);
        expect(exportPayload.report.mockExams!.weekly, isEmpty);
        expect(exportPayload.report.mockExams!.monthly, isEmpty);
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
        expect(report.schemaVersion, 5);
      },
    );

    test('includes bookmarked vocab ids in deterministic order', () async {
      const vocabAId = 'bookmark_vocab_a';
      const vocabBId = 'bookmark_vocab_b';
      const vocabCId = 'bookmark_vocab_c';
      const vocabALemma = 'bookmark_alpha';

      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: vocabAId,
              lemma: vocabALemma,
              meaning: 'alpha meaning',
            ),
          );
      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: vocabBId,
              lemma: 'bookmark_beta',
              meaning: 'beta meaning',
            ),
          );
      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: vocabCId,
              lemma: 'bookmark_gamma',
              meaning: 'gamma meaning',
            ),
          );

      await database
          .into(database.vocabUser)
          .insert(
            VocabUserCompanion.insert(
              vocabId: vocabCId,
              isBookmarked: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await database
          .into(database.vocabUser)
          .insert(
            VocabUserCompanion.insert(
              vocabId: vocabAId,
              isBookmarked: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await database
          .into(database.vocabUser)
          .insert(
            VocabUserCompanion.insert(
              vocabId: vocabBId,
              isBookmarked: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );

      final report = await reportRepository.buildCumulativeReport(
        track: 'M3',
        nowLocal: DateTime(2026, 2, 21, 12, 0),
      );

      expect(report.vocabBookmarks, isNotNull);
      expect(report.vocabBookmarks!.bookmarkedVocabIds, <String>[
        vocabAId,
        vocabBId,
        vocabCId,
      ]);
      expect(report.encodeCompact().contains(vocabAId), isTrue);
      expect(report.encodeCompact().contains(vocabALemma), isFalse);
      expect(report.customVocab, isNotNull);
      expect(report.customVocab!.lemmasById, isEmpty);
    });

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

    test('includes completed weekly and monthly mock summaries', () async {
      const testPlan = MockExamQuestionPlan(listeningCount: 3, readingCount: 3);
      final weeklySession = await mockExamSessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: testPlan,
        nowLocal: DateTime(2026, 2, 21, 9, 0),
      );
      final monthlySession = await mockExamSessionRepository.getOrCreateSession(
        type: MockExamType.monthly,
        track: 'M3',
        plan: testPlan,
        nowLocal: DateTime(2026, 2, 22, 9, 0),
      );

      await _completeMockSession(
        repository: mockExamAttemptRepository,
        session: weeklySession,
        listeningCorrectTarget: 2,
        readingCorrectTarget: 2,
      );
      await _completeMockSession(
        repository: mockExamAttemptRepository,
        session: monthlySession,
        listeningCorrectTarget: 2,
        readingCorrectTarget: 3,
      );

      final report = await reportRepository.buildCumulativeReport(
        track: 'M3',
        nowLocal: DateTime(2026, 2, 22, 23, 59),
      );

      expect(report.schemaVersion, 5);
      expect(report.mockExams, isNotNull);
      expect(report.mockExams!.weekly, hasLength(1));
      expect(report.mockExams!.monthly, hasLength(1));

      final weekly = report.mockExams!.weekly.first;
      expect(weekly.periodKey, '2026W08');
      expect(weekly.track, Track.m3);
      expect(weekly.totalCount, 20);
      expect(weekly.listeningCorrect, 2);
      expect(weekly.readingCorrect, 2);
      expect(weekly.correctCount, 4);
      expect(weekly.wrongCount, 16);

      final monthly = report.mockExams!.monthly.first;
      expect(monthly.periodKey, '202602');
      expect(monthly.track, Track.m3);
      expect(monthly.totalCount, 45);
      expect(monthly.listeningCorrect, 2);
      expect(monthly.readingCorrect, 3);
      expect(monthly.correctCount, 5);
      expect(monthly.wrongCount, 40);
    });
  });
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
