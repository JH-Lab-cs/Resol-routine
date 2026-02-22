import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/db_text_limits.dart';
import 'package:resol_routine/features/vocab/data/vocab_repository.dart';

void main() {
  group('VocabRepository', () {
    late AppDatabase database;
    late VocabRepository repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = VocabRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'adds normalized custom vocabulary and shows it in my vocabulary',
      () async {
        await repository.addVocabulary(
          lemma: '  analyze  ',
          meaning: '  분석하다  ',
          pos: '  verb  ',
          example: '  We analyze results daily.  ',
        );

        final inserted = await _loadSingleCustomVocabulary(database);

        expect(inserted.id.length, lessThanOrEqualTo(DbTextLimits.idMax));
        expect(inserted.lemma, 'analyze');
        expect(inserted.meaning, '분석하다');
        expect(inserted.pos, 'verb');
        expect(inserted.example, 'We analyze results daily.');

        final myVocabulary = await repository.listMyVocabulary();
        expect(myVocabulary.any((item) => item.id == inserted.id), isTrue);
      },
    );

    test('rejects empty lemma or meaning', () async {
      await expectLater(
        repository.addVocabulary(lemma: '   ', meaning: '뜻'),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        repository.addVocabulary(lemma: 'lemma', meaning: '   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects hidden unicode in lemma, meaning, pos and example', () async {
      await expectLater(
        repository.addVocabulary(lemma: 'sa\u200Bfe', meaning: '뜻'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.addVocabulary(lemma: 'safe', meaning: '뜻\u200B'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.addVocabulary(lemma: 'safe', meaning: '뜻', pos: 'n\u200B'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        repository.addVocabulary(
          lemma: 'safe',
          meaning: '뜻',
          example: 'example\u200B',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'rejects length overflow in lemma, meaning, pos and example',
      () async {
        await expectLater(
          repository.addVocabulary(
            lemma: 'l' * (DbTextLimits.lemmaMax + 1),
            meaning: '뜻',
          ),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          repository.addVocabulary(
            lemma: 'lemma',
            meaning: 'm' * (DbTextLimits.meaningMax + 1),
          ),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          repository.addVocabulary(
            lemma: 'lemma',
            meaning: '뜻',
            pos: 'p' * (DbTextLimits.lemmaMax + 1),
          ),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          repository.addVocabulary(
            lemma: 'lemma',
            meaning: '뜻',
            example: 'e' * (DbTextLimits.meaningMax + 1),
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('updates custom vocabulary', () async {
      await repository.addVocabulary(
        lemma: 'analyze',
        meaning: '분석하다',
        pos: 'verb',
        example: 'We analyze the data.',
      );
      final inserted = await _loadSingleCustomVocabulary(database);

      await repository.updateVocabulary(
        id: inserted.id,
        lemma: 'refine',
        meaning: '다듬다',
        pos: '',
        example: '  We refine the plan.  ',
      );

      final updated = await (database.select(
        database.vocabMaster,
      )..where((tbl) => tbl.id.equals(inserted.id))).getSingle();
      expect(updated.lemma, 'refine');
      expect(updated.meaning, '다듬다');
      expect(updated.pos, isNull);
      expect(updated.example, 'We refine the plan.');
    });

    test('rejects update for non-custom id', () async {
      await _insertVocabulary(
        database,
        id: 'seed_vocab',
        lemma: 'seed',
        meaning: '씨앗',
      );

      await expectLater(
        repository.updateVocabulary(
          id: 'seed_vocab',
          lemma: 'changed',
          meaning: '변경',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('deletes custom vocabulary and cascades vocab_user rows', () async {
      const customId = 'user_delete_target';
      await _insertVocabulary(
        database,
        id: customId,
        lemma: 'custom',
        meaning: '사용자 단어',
      );
      await database
          .into(database.vocabUser)
          .insert(
            VocabUserCompanion.insert(
              vocabId: customId,
              isBookmarked: const Value(true),
            ),
          );

      final deleted = await repository.deleteVocabulary(id: customId);
      expect(deleted, isTrue);

      final deletedVocab = await (database.select(
        database.vocabMaster,
      )..where((tbl) => tbl.id.equals(customId))).getSingleOrNull();
      final deletedVocabUser = await (database.select(
        database.vocabUser,
      )..where((tbl) => tbl.vocabId.equals(customId))).getSingleOrNull();

      expect(deletedVocab, isNull);
      expect(deletedVocabUser, isNull);
    });

    test('rejects delete for non-custom id', () async {
      await _insertVocabulary(
        database,
        id: 'seed_vocab',
        lemma: 'seed',
        meaning: '씨앗',
      );

      await expectLater(
        repository.deleteVocabulary(id: 'seed_vocab'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Future<void> _insertVocabulary(
  AppDatabase database, {
  required String id,
  required String lemma,
  required String meaning,
}) {
  return database
      .into(database.vocabMaster)
      .insert(
        VocabMasterCompanion.insert(id: id, lemma: lemma, meaning: meaning),
      );
}

Future<VocabMasterData> _loadSingleCustomVocabulary(
  AppDatabase database,
) async {
  final allRows = await (database.select(database.vocabMaster)).get();
  final customRows = allRows
      .where((row) => row.id.startsWith('user_'))
      .toList();
  expect(customRows, hasLength(1));
  return customRows.single;
}
