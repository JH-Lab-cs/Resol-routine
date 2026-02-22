import 'dart:io';

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';
import 'package:resol_routine/features/report/data/report_export_repository.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  group('Report round-trip', () {
    late AppDatabase database;
    late TodaySessionRepository sessionRepository;
    late TodayQuizRepository quizRepository;
    late ReportExportRepository exportRepository;
    late SharedReportsRepository sharedReportsRepository;
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
      exportRepository = ReportExportRepository(
        database: database,
        appVersionLoader: () async => '1.2.3+45',
      );
      sharedReportsRepository = SharedReportsRepository(database: database);
      vocabQuizResultsRepository = VocabQuizResultsRepository(
        database: database,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'exported payload can be imported and preserves summary counts',
      () async {
        final dayOne = await sessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 20, 8, 30),
        );
        final dayTwo = await sessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 21, 9, 45),
        );

        await quizRepository.saveAttemptIdempotent(
          sessionId: dayOne.sessionId,
          questionId: dayOne.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: dayOne.sessionId,
          questionId: dayOne.items[1].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: dayOne.sessionId,
          questionId: dayOne.items[3].questionId,
          selectedAnswer: 'C',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.evidence,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: dayTwo.sessionId,
          questionId: dayTwo.items[0].questionId,
          selectedAnswer: 'D',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: dayTwo.sessionId,
          questionId: dayTwo.items[4].questionId,
          selectedAnswer: 'E',
          isCorrect: true,
        );

        const customVocabId = 'probe_vocab_20260221';
        const secondCustomVocabId = 'probe_vocab_20260221_b';
        const bookmarkOnlyVocabId = 'probe_vocab_20260221_c';
        const customLemma = 'lemma_probe_token_24680';
        const customMeaning = 'meaning_probe_token_24680';
        const customExample = 'example_probe_token_24680';
        await database
            .into(database.vocabMaster)
            .insert(
              VocabMasterCompanion.insert(
                id: customVocabId,
                lemma: customLemma,
                meaning: customMeaning,
                example: const Value(customExample),
              ),
            );
        await database
            .into(database.vocabMaster)
            .insert(
              VocabMasterCompanion.insert(
                id: secondCustomVocabId,
                lemma: 'lemma_probe_token_24681',
                meaning: 'meaning_probe_token_24681',
              ),
            );
        await database
            .into(database.vocabMaster)
            .insert(
              VocabMasterCompanion.insert(
                id: bookmarkOnlyVocabId,
                lemma: 'lemma_probe_token_24682',
                meaning: 'meaning_probe_token_24682',
              ),
            );
        final expectedWrongVocabIds = <String>[
          customVocabId,
          secondCustomVocabId,
        ]..sort();
        final expectedBookmarkedVocabIds = <String>[
          customVocabId,
          secondCustomVocabId,
          bookmarkOnlyVocabId,
        ]..sort();

        await database
            .into(database.vocabUser)
            .insert(
              VocabUserCompanion.insert(
                vocabId: customVocabId,
                isBookmarked: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
        await database
            .into(database.vocabUser)
            .insert(
              VocabUserCompanion.insert(
                vocabId: secondCustomVocabId,
                isBookmarked: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
        await database
            .into(database.vocabUser)
            .insert(
              VocabUserCompanion.insert(
                vocabId: bookmarkOnlyVocabId,
                isBookmarked: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );

        await vocabQuizResultsRepository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 18,
          wrongVocabIds: expectedWrongVocabIds.reversed.toList(),
        );

        final exportPayload = await exportRepository.buildExportPayload(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 21, 23, 59),
        );

        expect(exportPayload.jsonPayload.contains('\n'), isFalse);
        expect(exportPayload.report.schemaVersion, 3);
        expect(exportPayload.report.days, hasLength(2));
        expect(exportPayload.report.days.first.dayKey, '20260221');
        expect(
          exportPayload.report.vocabBookmarks!.bookmarkedVocabIds,
          expectedBookmarkedVocabIds,
        );

        final importedId = await sharedReportsRepository.importFromJson(
          source: exportPayload.fileName,
          payloadJson: exportPayload.jsonPayload,
        );

        final summaries = await sharedReportsRepository.listSummaries();
        expect(summaries, hasLength(1));
        expect(summaries.first.id, importedId);
        expect(summaries.first.track, 'M3');
        expect(summaries.first.latestDayKey, '20260221');
        expect(summaries.first.dayCount, 2);
        expect(summaries.first.totalSolvedCount, 5);
        expect(summaries.first.totalWrongCount, 3);
        expect(summaries.first.topWrongReasonTag, 'VOCAB');

        final detail = await sharedReportsRepository.loadById(importedId);
        expect(detail.report.schemaVersion, 3);
        expect(detail.report.appVersion, '1.2.3+45');
        expect(detail.report.days, hasLength(2));
        expect(detail.report.days.first.vocabQuiz, isNotNull);
        expect(detail.report.days.first.vocabQuiz!.correctCount, 18);
        expect(
          detail.report.days.first.vocabQuiz!.wrongVocabIds,
          expectedWrongVocabIds,
        );
        expect(detail.report.days.first.questions, hasLength(2));
        expect(detail.report.days.last.questions, hasLength(3));
        expect(
          detail.report.vocabBookmarks!.bookmarkedVocabIds,
          expectedBookmarkedVocabIds,
        );

        final questionRow = await (database.select(
          database.questions,
        )..limit(1)).getSingle();
        final explanationRow = await (database.select(
          database.explanations,
        )..where((tbl) => tbl.questionId.equals(questionRow.id))).getSingle();
        final scriptRow = await (database.select(
          database.scripts,
        )..limit(1)).getSingle();
        final passageRow = await (database.select(
          database.passages,
        )..limit(1)).getSingle();

        final payload = exportPayload.jsonPayload;
        expect(payload.contains(customVocabId), isTrue);
        expect(payload.contains(bookmarkOnlyVocabId), isTrue);
        expect(payload.contains(customLemma), isFalse);
        expect(payload.contains(customMeaning), isFalse);
        expect(payload.contains(customExample), isFalse);
        expect(payload.contains(questionRow.prompt), isFalse);
        expect(payload.contains(questionRow.optionsJson.a), isFalse);
        expect(payload.contains(explanationRow.whyCorrectKo), isFalse);
        expect(payload.contains(scriptRow.sentencesJson.first.text), isFalse);
        expect(payload.contains(passageRow.sentencesJson.first.text), isFalse);
      },
    );

    test('rejects hidden unicode in student displayName on import', () async {
      final report = _minimalValidReport(displayName: 'Min\u200Bsu');

      await expectLater(
        sharedReportsRepository.importFromJson(
          source: 'resolroutine_report_20260221_M3.json',
          payloadJson: report.encodeCompact(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects hidden unicode in question typeTag on import', () async {
      final report = _minimalValidReport(typeTag: 'L\u200B1');

      await expectLater(
        sharedReportsRepository.importFromJson(
          source: 'resolroutine_report_20260221_M3.json',
          payloadJson: report.encodeCompact(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('keeps vocab-only day entries through export and import', () async {
      final session = await sessionRepository.getOrCreateSession(
        track: 'M3',
        nowLocal: DateTime(2026, 2, 21, 8, 0),
      );
      await quizRepository.saveAttemptIdempotent(
        sessionId: session.sessionId,
        questionId: session.items[0].questionId,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      final vocabRow = await (database.select(
        database.vocabMaster,
      )..limit(1)).getSingle();

      await vocabQuizResultsRepository.upsertDailyResult(
        dayKey: '20260222',
        track: 'M3',
        totalCount: 20,
        correctCount: 19,
        wrongVocabIds: <String>[vocabRow.id],
      );

      final exportPayload = await exportRepository.buildExportPayload(
        track: 'M3',
        nowLocal: DateTime(2026, 2, 22, 9, 30),
      );

      expect(exportPayload.report.days.map((day) => day.dayKey), <String>[
        '20260222',
        '20260221',
      ]);
      expect(exportPayload.report.days.first.solvedCount, 0);
      expect(exportPayload.report.days.first.questions, isEmpty);
      expect(exportPayload.report.days.first.vocabQuiz, isNotNull);
      expect(exportPayload.report.days.first.vocabQuiz!.correctCount, 19);

      final importedId = await sharedReportsRepository.importFromJson(
        source: exportPayload.fileName,
        payloadJson: exportPayload.jsonPayload,
      );

      final summaries = await sharedReportsRepository.listSummaries();
      expect(summaries, hasLength(1));
      expect(summaries.first.id, importedId);
      expect(summaries.first.dayCount, 2);
      expect(summaries.first.totalSolvedCount, 1);

      final detail = await sharedReportsRepository.loadById(importedId);
      expect(detail.report.days, hasLength(2));
      expect(detail.report.days.first.dayKey, '20260222');
      expect(detail.report.days.first.questions, isEmpty);
      expect(detail.report.days.first.vocabQuiz, isNotNull);
      expect(detail.report.days.first.vocabQuiz!.wrongVocabIds, <String>[
        vocabRow.id,
      ]);
    });
  });
}

ReportSchema _minimalValidReport({
  String displayName = 'Minsu',
  String typeTag = 'L1',
}) {
  return ReportSchema.v1(
    generatedAt: DateTime.utc(2026, 2, 21, 12),
    appVersion: '1.0.0+1',
    student: ReportStudent(
      role: 'STUDENT',
      displayName: displayName,
      track: Track.m3,
    ),
    days: <ReportDay>[
      ReportDay(
        dayKey: '20260221',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 0,
        listeningCorrect: 1,
        readingCorrect: 0,
        wrongReasonCounts: const <WrongReasonTag, int>{},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-L-1',
            skill: Skill.listening,
            typeTag: typeTag,
            isCorrect: true,
            wrongReasonTag: null,
          ),
        ],
      ),
    ],
  );
}
