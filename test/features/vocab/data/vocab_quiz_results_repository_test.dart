import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';

void main() {
  group('VocabQuizResultsRepository', () {
    late AppDatabase database;
    late VocabQuizResultsRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = VocabQuizResultsRepository(database: database);
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
        wrongVocabIds: <String>['vocab_z', 'vocab_a', 'vocab_a'],
      );

      final first = await repository.loadByDayKey(
        dayKey: '20260221',
        track: 'M3',
      );
      expect(first, isNotNull);
      expect(first!.correctCount, 18);
      expect(first.wrongVocabIds, <String>['vocab_a', 'vocab_z']);

      await repository.upsertDailyResult(
        dayKey: '20260221',
        track: 'M3',
        totalCount: 20,
        correctCount: 19,
        wrongVocabIds: <String>['vocab_x'],
      );

      final second = await repository.loadByDayKey(
        dayKey: '20260221',
        track: 'M3',
      );
      expect(second, isNotNull);
      expect(second!.correctCount, 19);
      expect(second.wrongVocabIds, <String>['vocab_x']);

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
          totalCount: 21,
          correctCount: 20,
          wrongVocabIds: const <String>[],
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        repository.upsertDailyResult(
          dayKey: '20260221',
          track: 'M3',
          totalCount: 10,
          correctCount: 11,
          wrongVocabIds: const <String>[],
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
