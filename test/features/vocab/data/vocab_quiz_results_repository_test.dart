import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  group('VocabQuizResultsRepository', () {
    late AppDatabase database;
    late VocabQuizResultsRepository repository;
    late List<String> seededIds;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = VocabQuizResultsRepository(database: database);
      seededIds = <String>['vocab_a', 'vocab_b', 'vocab_c'];
      for (var i = 0; i < seededIds.length; i++) {
        await database
            .into(database.vocabMaster)
            .insert(
              VocabMasterCompanion.insert(
                id: seededIds[i],
                lemma: 'lemma_${i + 1}',
                meaning: 'meaning_${i + 1}',
              ),
            );
      }
    });

    tearDown(() async {
      await database.close();
    });

    test('upsertDailyResult is idempotent per dayKey and track', () async {
      await repository.upsertDailyResult(
        dayKey: '20260221',
        track: 'M3',
        totalCount: 20,
        correctCount: 18,
        wrongVocabIds: <String>[seededIds[2], seededIds[0]],
      );

      final first = await repository.loadByDayKey(
        dayKey: '20260221',
        track: 'M3',
      );
      expect(first, isNotNull);
      expect(first!.correctCount, 18);
      expect(first.wrongVocabIds, <String>[seededIds[0], seededIds[2]]);

      await repository.upsertDailyResult(
        dayKey: '20260221',
        track: 'M3',
        totalCount: 20,
        correctCount: 19,
        wrongVocabIds: <String>[seededIds[1]],
      );

      final second = await repository.loadByDayKey(
        dayKey: '20260221',
        track: 'M3',
      );
      expect(second, isNotNull);
      expect(second!.correctCount, 19);
      expect(second.wrongVocabIds, <String>[seededIds[1]]);

      final rowCount = await (database.select(database.vocabQuizResults)).get();
      expect(rowCount, hasLength(1));
    });

    test('rejects hidden unicode in wrongVocabIds', () async {
      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 19,
          wrongVocabIds: <String>['vocab_\u200Bid'],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid count ranges', () async {
      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 0,
          correctCount: 20,
          wrongVocabIds: const <String>['vocab_a'],
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 21,
          wrongVocabIds: const <String>['vocab_a'],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects wrongVocabIds length that differs from wrongCount', () async {
      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 19,
          wrongVocabIds: <String>[seededIds[0], seededIds[1]],
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 20,
          wrongVocabIds: <String>[seededIds[0]],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicated wrongVocabIds', () async {
      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 18,
          wrongVocabIds: <String>[seededIds[0], seededIds[0]],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unknown vocab ids in wrongVocabIds', () async {
      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 20,
          correctCount: 19,
          wrongVocabIds: const <String>['vocab_missing'],
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
