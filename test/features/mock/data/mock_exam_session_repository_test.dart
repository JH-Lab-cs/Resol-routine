import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_period_key.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';

void main() {
  group('MockExamSessionRepository', () {
    late AppDatabase database;
    late MockExamSessionRepository repository;
    late MockExamAttemptRepository attemptRepository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = MockExamSessionRepository(database: database);
      attemptRepository = MockExamAttemptRepository(database: database);
      await _seedQuestionPool(
        database,
        track: 'M3',
        listeningCount: 12,
        readingCount: 12,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('returns same session id for same type-period-track', () async {
      final nowLocal = DateTime.utc(2026, 2, 20, 1, 30);
      final plan = MockExamSessionRepository.weeklyDefaultPlan;

      final first = await repository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: plan,
        nowLocal: nowLocal,
      );
      final second = await repository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: plan,
        nowLocal: nowLocal,
      );

      expect(first.sessionId, second.sessionId);
      expect(first.periodKey, second.periodKey);
      expect(
        first.items.map((item) => item.questionId).toList(),
        hasLength(20),
      );
      expect(first.items.map((item) => item.questionId).toSet(), hasLength(20));

      expect(
        first.items.take(10).every((item) => item.skill == Skill.listening),
        isTrue,
      );
      expect(
        first.items.skip(10).every((item) => item.skill == Skill.reading),
        isTrue,
      );

      expect(first.periodKey, startsWith('2026W'));
      validateMockExamPeriodKey(
        type: MockExamType.weekly,
        periodKey: first.periodKey,
      );
    });

    test(
      'deterministically selects same question set within same period',
      () async {
        final nowLocal = DateTime.utc(2026, 2, 20, 1, 30);
        final plan = MockExamSessionRepository.weeklyDefaultPlan;

        final first = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: plan,
          nowLocal: nowLocal,
        );
        final firstQuestionIds = first.items
            .map((item) => item.questionId)
            .toList(growable: false);

        await (database.delete(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(first.sessionId))).go();

        final second = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: plan,
          nowLocal: nowLocal,
        );
        final secondQuestionIds = second.items
            .map((item) => item.questionId)
            .toList(growable: false);

        expect(firstQuestionIds, orderedEquals(secondQuestionIds));
      },
    );

    test(
      'throws INSUFFICIENT_QUESTIONS when question pool is too small',
      () async {
        expect(
          () => repository.getOrCreateSession(
            type: MockExamType.weekly,
            track: 'M3',
            plan: const MockExamQuestionPlan(
              listeningCount: 13,
              readingCount: 10,
            ),
            nowLocal: DateTime.utc(2026, 2, 20, 1, 30),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('INSUFFICIENT_QUESTIONS'),
            ),
          ),
        );
      },
    );

    test(
      'listRecent returns summaries sorted by period with score counts',
      () async {
        final olderSession = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 20, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: olderSession.sessionId,
          questionId: olderSession.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: olderSession.sessionId,
          questionId: olderSession.items[1].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );

        final newerSession = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 27, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: newerSession.sessionId,
          questionId: newerSession.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: newerSession.sessionId,
          questionId: newerSession.items[1].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        final summaries = await repository.listRecent(
          type: MockExamType.weekly,
          track: 'M3',
          limit: 10,
        );

        expect(summaries, hasLength(2));
        expect(summaries.first.sessionId, newerSession.sessionId);
        expect(summaries.first.correctCount, 2);
        expect(summaries.first.wrongCount, 0);

        expect(summaries.last.sessionId, olderSession.sessionId);
        expect(summaries.last.correctCount, 1);
        expect(summaries.last.wrongCount, 1);
      },
    );

    test(
      'deleteSessionById removes session items and attempts together',
      () async {
        final session = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 3, 2, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: session.sessionId,
          questionId: session.items[0].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );

        await repository.deleteSessionById(session.sessionId);

        final deletedSession = await (database.select(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(session.sessionId))).getSingleOrNull();
        final remainingItems = await (database.select(
          database.mockExamSessionItems,
        )..where((tbl) => tbl.sessionId.equals(session.sessionId))).get();
        final remainingAttempts = await (database.select(
          database.attempts,
        )..where((tbl) => tbl.mockSessionId.equals(session.sessionId))).get();

        expect(deletedSession, isNull);
        expect(remainingItems, isEmpty);
        expect(remainingAttempts, isEmpty);
      },
    );

    test(
      'pruneOldSessions keeps recent completed sessions and preserves in-progress sessions',
      () async {
        final weeklyIds = <int>[];
        final monthlyIds = <int>[];
        for (var i = 0; i < 60; i++) {
          final completedAt = DateTime.utc(
            2026,
            12,
            31,
          ).subtract(Duration(days: i * 7));
          final weekValue = (i % 52) + 1;
          final year = 2026 - (i ~/ 52);
          final periodKey = '${year}W${weekValue.toString().padLeft(2, '0')}';
          final id = await database
              .into(database.mockExamSessions)
              .insert(
                MockExamSessionsCompanion.insert(
                  examType: MockExamType.weekly.dbValue,
                  periodKey: periodKey,
                  track: 'M3',
                  plannedItems: 20,
                  completedItems: const Value(20),
                  completedAt: Value(completedAt),
                ),
              );
          weeklyIds.add(id);
        }
        for (var i = 0; i < 20; i++) {
          final completedAt = DateTime.utc(
            2026,
            12,
            31,
          ).subtract(Duration(days: i * 30));
          final monthDate = DateTime.utc(2026, 12 - i, 1);
          final periodKey =
              '${monthDate.year.toString().padLeft(4, '0')}${monthDate.month.toString().padLeft(2, '0')}';
          final id = await database
              .into(database.mockExamSessions)
              .insert(
                MockExamSessionsCompanion.insert(
                  examType: MockExamType.monthly.dbValue,
                  periodKey: periodKey,
                  track: 'M3',
                  plannedItems: 45,
                  completedItems: const Value(45),
                  completedAt: Value(completedAt),
                ),
              );
          monthlyIds.add(id);
        }

        final inProgressWeeklyId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.weekly.dbValue,
                periodKey: '2026W53',
                track: 'M3',
                plannedItems: 20,
                completedItems: const Value(3),
                completedAt: const Value(null),
              ),
            );
        final inProgressMonthlyId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.monthly.dbValue,
                periodKey: '202701',
                track: 'M3',
                plannedItems: 45,
                completedItems: const Value(4),
                completedAt: const Value(null),
              ),
            );

        await repository.pruneOldSessions(weeklyKeep: 52, monthlyKeep: 12);

        final remainingWeeklyCompleted = await database
            .customSelect(
              'SELECT id FROM mock_exam_sessions '
              'WHERE exam_type = ? AND completed_at IS NOT NULL '
              'ORDER BY completed_at DESC, id DESC',
              variables: [Variable<String>(MockExamType.weekly.dbValue)],
              readsFrom: {database.mockExamSessions},
            )
            .get();
        final remainingMonthlyCompleted = await database
            .customSelect(
              'SELECT id FROM mock_exam_sessions '
              'WHERE exam_type = ? AND completed_at IS NOT NULL '
              'ORDER BY completed_at DESC, id DESC',
              variables: [Variable<String>(MockExamType.monthly.dbValue)],
              readsFrom: {database.mockExamSessions},
            )
            .get();

        expect(remainingWeeklyCompleted, hasLength(52));
        expect(remainingMonthlyCompleted, hasLength(12));
        expect(
          remainingWeeklyCompleted.map((row) => row.read<int>('id')).toSet(),
          equals(weeklyIds.take(52).toSet()),
        );
        expect(
          remainingMonthlyCompleted.map((row) => row.read<int>('id')).toSet(),
          equals(monthlyIds.take(12).toSet()),
        );

        final inProgressWeekly = await (database.select(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(inProgressWeeklyId))).getSingleOrNull();
        final inProgressMonthly =
            await (database.select(database.mockExamSessions)
                  ..where((tbl) => tbl.id.equals(inProgressMonthlyId)))
                .getSingleOrNull();
        expect(inProgressWeekly, isNotNull);
        expect(inProgressMonthly, isNotNull);
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
