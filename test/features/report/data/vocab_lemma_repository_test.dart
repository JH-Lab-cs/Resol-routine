import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/db_text_limits.dart';
import 'package:resol_routine/features/report/data/vocab_lemma_repository.dart';

void main() {
  group('VocabLemmaRepository', () {
    late AppDatabase database;
    late VocabLemmaRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = VocabLemmaRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('loads 1800 ids without hitting sqlite IN variable limit', () async {
      final ids = List<String>.generate(
        1800,
        (index) => 'chunk_vocab_${index.toString().padLeft(4, '0')}',
      );
      await _seedVocabMaster(database, ids);

      final lemmaMap = await repository.loadLemmaMapByVocabIds(ids);

      expect(lemmaMap.length, 1800);
      expect(lemmaMap[ids.first], 'lemma_0');
      expect(lemmaMap[ids[899]], 'lemma_899');
      expect(lemmaMap[ids.last], 'lemma_1799');
    });

    test('returns only existing ids when some ids are missing', () async {
      const existingA = 'existing_vocab_a';
      const existingB = 'existing_vocab_b';
      await _seedVocabMaster(database, <String>[existingA, existingB]);

      final lemmaMap = await repository.loadLemmaMapByVocabIds(<String>[
        existingA,
        'missing_vocab',
        existingB,
      ]);

      expect(lemmaMap.keys.toList(), <String>[existingA, existingB]);
      expect(lemmaMap[existingA], 'lemma_0');
      expect(lemmaMap[existingB], 'lemma_1');
      expect(lemmaMap.containsKey('missing_vocab'), isFalse);
    });

    test('accepts duplicate ids and returns unique map entries', () async {
      await _seedVocabMaster(database, <String>['dup_a', 'dup_b']);

      final lemmaMap = await repository.loadLemmaMapByVocabIds(<String>[
        'dup_b',
        'dup_a',
        'dup_b',
        'dup_a',
      ]);

      expect(lemmaMap.keys.toList(), <String>['dup_b', 'dup_a']);
      expect(lemmaMap['dup_b'], 'lemma_1');
      expect(lemmaMap['dup_a'], 'lemma_0');
    });

    test('allows raw input > 2000 when deduplicated size <= 2000', () async {
      final dedupedIds = List<String>.generate(
        2000,
        (index) => 'dedupe_vocab_${index.toString().padLeft(4, '0')}',
      );
      await _seedVocabMaster(database, dedupedIds);

      final withDuplicates = <String>[...dedupedIds, ...dedupedIds.take(500)];

      final lemmaMap = await repository.loadLemmaMapByVocabIds(withDuplicates);

      expect(lemmaMap.length, 2000);
      expect(lemmaMap[dedupedIds.first], 'lemma_0');
      expect(lemmaMap[dedupedIds.last], 'lemma_1999');
    });

    test('rejects deduplicated input length over 2000', () async {
      final tooManyDedupedIds = List<String>.generate(
        2001,
        (index) => 'dedupe_oversized_vocab_$index',
      );

      expect(
        () => repository.loadLemmaMapByVocabIds(tooManyDedupedIds),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects raw input length over 6000', () async {
      final tooManyRawIds = List<String>.generate(
        6001,
        (index) => 'raw_guard_vocab_${index % 2000}',
      );

      expect(
        () => repository.loadLemmaMapByVocabIds(tooManyRawIds),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects id length overflow', () async {
      final tooLongId = 'x' * (DbTextLimits.idMax + 1);

      expect(
        () => repository.loadLemmaMapByVocabIds(<String>[tooLongId]),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips rows whose lemma contains hidden unicode', () async {
      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: 'safe_vocab',
              lemma: 'safeLemma',
              meaning: 'safe meaning',
            ),
          );
      await database
          .into(database.vocabMaster)
          .insert(
            VocabMasterCompanion.insert(
              id: 'unsafe_vocab',
              lemma: 'unsafe\u200BLemma',
              meaning: 'unsafe meaning',
            ),
          );

      final lemmaMap = await repository.loadLemmaMapByVocabIds(<String>[
        'safe_vocab',
        'unsafe_vocab',
      ]);

      expect(lemmaMap['safe_vocab'], 'safeLemma');
      expect(lemmaMap.containsKey('unsafe_vocab'), isFalse);
    });
  });
}

Future<void> _seedVocabMaster(AppDatabase database, List<String> ids) async {
  await database.batch((batch) {
    batch.insertAll(database.vocabMaster, <VocabMasterCompanion>[
      for (var i = 0; i < ids.length; i++)
        VocabMasterCompanion.insert(
          id: ids[i],
          lemma: 'lemma_$i',
          meaning: 'meaning_$i',
        ),
    ]);
  });
}
