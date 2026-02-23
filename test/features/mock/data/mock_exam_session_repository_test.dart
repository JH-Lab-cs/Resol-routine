import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_period_key.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';

void main() {
  group('MockExamSessionRepository', () {
    late AppDatabase database;
    late MockExamSessionRepository repository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = MockExamSessionRepository(database: database);
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
