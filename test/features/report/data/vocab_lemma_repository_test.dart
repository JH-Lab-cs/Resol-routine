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

    test('rejects input length over 2000', () async {
      final tooManyIds = List<String>.generate(
        2001,
        (index) => 'oversized_vocab_$index',
      );

      expect(
        () => repository.loadLemmaMapByVocabIds(tooManyIds),
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
