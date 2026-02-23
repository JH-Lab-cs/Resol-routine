import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';

void main() {
  group('MockExamAttemptRepository', () {
    late AppDatabase database;
    late MockExamSessionRepository sessionRepository;
    late MockExamAttemptRepository attemptRepository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      sessionRepository = MockExamSessionRepository(database: database);
      attemptRepository = MockExamAttemptRepository(database: database);

      await _seedQuestionPool(
        database,
        track: 'M3',
        listeningCount: 6,
        readingCount: 6,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('idempotent save does not increase completed items twice', () async {
      final bundle = await sessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
        nowLocal: DateTime.utc(2026, 2, 20, 1, 30),
      );
      final questionId = bundle.items.first.questionId;

      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: bundle.sessionId,
        questionId: questionId,
        selectedAnswer: 'B',
        isCorrect: false,
        wrongReasonTag: WrongReasonTag.vocab,
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: bundle.sessionId,
        questionId: questionId,
        selectedAnswer: 'A',
        isCorrect: true,
      );

      final refreshed = await (database.select(
        database.mockExamSessions,
      )..where((tbl) => tbl.id.equals(bundle.sessionId))).getSingle();
      expect(refreshed.completedItems, 1);

      final attemptsQuery = database.select(database.attempts)
        ..where((tbl) => tbl.mockSessionId.equals(bundle.sessionId))
        ..where((tbl) => tbl.questionId.equals(questionId));
      final attempts = await attemptsQuery.get();
      expect(attempts, hasLength(1));
      expect(attempts.single.sessionId, isNull);
      expect(attempts.single.mockSessionId, bundle.sessionId);
    });

    test(
      'findFirstUnansweredOrderIndex returns next unanswered index',
      () async {
        final bundle = await sessionRepository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 20, 1, 30),
        );

        final beforeAny = await attemptRepository.findFirstUnansweredOrderIndex(
          mockSessionId: bundle.sessionId,
        );
        expect(beforeAny, 0);

        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: bundle.sessionId,
          questionId: bundle.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        final afterFirst = await attemptRepository
            .findFirstUnansweredOrderIndex(mockSessionId: bundle.sessionId);
        expect(afterFirst, 1);

        for (var index = 1; index < bundle.items.length; index++) {
          await attemptRepository.saveAttemptIdempotent(
            mockSessionId: bundle.sessionId,
            questionId: bundle.items[index].questionId,
            selectedAnswer: 'A',
            isCorrect: true,
          );
        }

        final afterAll = await attemptRepository.findFirstUnansweredOrderIndex(
          mockSessionId: bundle.sessionId,
        );
        expect(afterAll, bundle.plannedItems);
      },
    );

    test(
      'loadCompletionReport aggregates skill counts and top wrong reason',
      () async {
        final bundle = await sessionRepository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 20, 1, 30),
        );

        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: bundle.sessionId,
          questionId: bundle.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: bundle.sessionId,
          questionId: bundle.items[1].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: bundle.sessionId,
          questionId: bundle.items[2].questionId,
          selectedAnswer: 'C',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: bundle.sessionId,
          questionId: bundle.items[3].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        final report = await attemptRepository.loadCompletionReport(
          bundle.sessionId,
        );
        expect(report.listeningCorrectCount, 1);
        expect(report.readingCorrectCount, 1);
        expect(report.wrongCount, 2);
        expect(report.topWrongReasonTag, WrongReasonTag.vocab);

        final refreshed = await (database.select(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(bundle.sessionId))).getSingle();
        expect(refreshed.completedItems, 4);
        expect(refreshed.completedAt, isNotNull);
      },
    );
  });
}

Future<void> _seedQuestionPool(
  AppDatabase database, {
  required String track,
  required int listeningCount,
  required int readingCount,
}) async {
  final packId = 'pack_$track';
  final scriptId = 'script_$track';
  final passageId = 'passage_$track';

  await database
      .into(database.contentPacks)
      .insert(
        ContentPacksCompanion.insert(
          id: packId,
          version: 1,
          locale: 'en-US',
          title: 'Mock Pack $track',
          checksum: 'sha256:$packId',
        ),
      );

  await database
      .into(database.scripts)
      .insert(
        ScriptsCompanion.insert(
          id: scriptId,
          packId: packId,
          sentencesJson: const <Sentence>[Sentence(id: 's1', text: 'line')],
          turnsJson: const <Turn>[
            Turn(speaker: 'S1', sentenceIds: <String>['s1']),
          ],
          ttsPlanJson: const TtsPlan(
            repeatPolicy: <String, Object?>{
              'mode': 'per_turn',
              'repeatCount': 1,
            },
            pauseRangeMs: NumericRange(min: 300, max: 600),
            rateRange: NumericRange(min: 0.95, max: 1.05),
            pitchRange: NumericRange(min: 0.0, max: 1.2),
            voiceRoles: <String, String>{
              'S1': 'en-US-Standard-C',
              'S2': 'en-US-Standard-E',
              'N': 'en-US-Standard-A',
            },
          ),
          orderIndex: 0,
        ),
      );

  await database
      .into(database.passages)
      .insert(
        PassagesCompanion.insert(
          id: passageId,
          packId: packId,
          sentencesJson: const <Sentence>[Sentence(id: 'p1', text: 'line')],
          orderIndex: 0,
        ),
      );

  const options = OptionMap(
    a: 'Alpha',
    b: 'Beta',
    c: 'Gamma',
    d: 'Delta',
    e: 'Epsilon',
  );

  for (var i = 0; i < listeningCount; i++) {
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: 'Q_${track}_L_${i + 1}',
            skill: Skill.listening.dbValue,
            typeTag: 'L${i + 1}',
            track: track,
            difficulty: 2,
            passageId: const Value(null),
            scriptId: Value(scriptId),
            prompt: 'Listening question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: i,
          ),
        );
  }

  for (var i = 0; i < readingCount; i++) {
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: 'Q_${track}_R_${i + 1}',
            skill: Skill.reading.dbValue,
            typeTag: 'R${i + 1}',
            track: track,
            difficulty: 2,
            passageId: Value(passageId),
            scriptId: const Value(null),
            prompt: 'Reading question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: i + listeningCount,
          ),
        );
  }
}
