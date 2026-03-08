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
        expect(inserted.sourceTag, 'USER_CUSTOM');
        expect(inserted.targetMinTrack, isNull);
        expect(inserted.targetMaxTrack, isNull);
        expect(inserted.difficultyBand, isNull);
        expect(inserted.frequencyTier, isNull);

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

    test(
      'soft deletes custom vocabulary and removes vocab_user rows',
      () async {
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

        expect(deletedVocab, isNotNull);
        expect(deletedVocab!.deletedAt, isNotNull);
        expect(deletedVocabUser, isNull);
      },
    );

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

    test(
      'buildQuiz includes bookmarked custom vocabulary and keeps selection invariants',
      () async {
        const customBookmarkedIds = <String>[
          'user_custom_quiz_a',
          'user_custom_quiz_b',
          'user_custom_quiz_c',
        ];
        await _seedQuizVocabulary(
          database,
          baseCount: 27,
          customBookmarkedIds: customBookmarkedIds,
        );

        final fixedNow = DateTime.utc(2026, 2, 23, 9, 0);
        final firstQuiz = await repository.buildQuiz(
          nowLocal: fixedNow,
          count: 20,
        );
        final secondQuiz = await repository.buildQuiz(
          nowLocal: fixedNow,
          count: 20,
        );

        expect(firstQuiz.length, 20);
        final quizIds = firstQuiz.map((question) => question.vocabId).toList();
        expect(quizIds.toSet().length, 20);
        for (final customId in customBookmarkedIds) {
          expect(quizIds, contains(customId));
        }

        for (final question in firstQuiz) {
          expect(question.options, hasLength(5));
          expect(
            question.correctOptionIndex,
            inInclusiveRange(0, question.options.length - 1),
          );
          expect(
            question.options[question.correctOptionIndex],
            question.correctMeaning,
          );
          expect(
            question.options.where(
              (option) => option == question.correctMeaning,
            ),
            hasLength(1),
          );
        }

        expect(
          firstQuiz.map(_quizSnapshot).toList(),
          secondQuiz.map(_quizSnapshot).toList(),
        );
      },
    );

    test(
      'buildQuiz selects only custom bookmarked items when they are at least 20',
      () async {
        final customBookmarkedIds = List<String>.generate(
          22,
          (index) => 'user_custom_pool_${index.toString().padLeft(2, '0')}',
        );
        await _seedQuizVocabulary(
          database,
          baseCount: 12,
          customBookmarkedIds: customBookmarkedIds,
        );

        final quiz = await repository.buildQuiz(
          nowLocal: DateTime.utc(2026, 2, 23, 9, 0),
          count: 20,
        );

        expect(quiz.length, 20);
        expect(quiz.map((question) => question.vocabId).toSet().length, 20);
        for (final question in quiz) {
          expect(question.vocabId.startsWith('user_'), isTrue);
        }
      },
    );

    test(
      'hides soft-deleted custom vocabulary from lists and search',
      () async {
        await _insertVocabulary(
          database,
          id: 'user_active_vocab',
          lemma: 'active_word',
          meaning: '활성 단어',
        );
        await _insertVocabulary(
          database,
          id: 'user_deleted_vocab',
          lemma: 'deleted_word',
          meaning: '삭제 단어',
        );

        final deleted = await repository.deleteVocabulary(
          id: 'user_deleted_vocab',
        );
        expect(deleted, isTrue);

        final myVocabulary = await repository.listMyVocabulary();
        expect(
          myVocabulary.map((item) => item.id),
          contains('user_active_vocab'),
        );
        expect(
          myVocabulary.map((item) => item.id),
          isNot(contains('user_deleted_vocab')),
        );

        final searchResult = await repository.listMyVocabulary(
          searchTerm: 'deleted_word',
        );
        expect(searchResult, isEmpty);
      },
    );

    test('excludes soft-deleted custom vocabulary from quiz pool', () async {
      const deletedCustomId = 'user_deleted_quiz_vocab';
      await _seedQuizVocabulary(
        database,
        baseCount: 30,
        customBookmarkedIds: <String>['user_quiz_custom_a', deletedCustomId],
      );
      await (database.update(
        database.vocabMaster,
      )..where((tbl) => tbl.id.equals(deletedCustomId))).write(
        VocabMasterCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );

      final quiz = await repository.buildQuiz(
        nowLocal: DateTime.utc(2026, 2, 23, 9, 0),
        count: 20,
      );
      expect(quiz.length, 20);
      expect(
        quiz.map((question) => question.vocabId),
        isNot(contains(deletedCustomId)),
      );
    });

    test('rejects update for soft-deleted custom id', () async {
      const deletedCustomId = 'user_deleted_update_target';
      await _insertVocabulary(
        database,
        id: deletedCustomId,
        lemma: 'custom',
        meaning: '사용자 단어',
      );
      await repository.deleteVocabulary(id: deletedCustomId);

      await expectLater(
        repository.updateVocabulary(
          id: deletedCustomId,
          lemma: 'updated',
          meaning: '수정',
        ),
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

Future<void> _seedQuizVocabulary(
  AppDatabase database, {
  required int baseCount,
  required List<String> customBookmarkedIds,
}) async {
  await database.batch((batch) {
    batch.insertAll(database.vocabMaster, <VocabMasterCompanion>[
      for (var i = 0; i < baseCount; i++)
        VocabMasterCompanion.insert(
          id: 'seed_quiz_vocab_$i',
          lemma: 'seedLemma$i',
          meaning: 'seedMeaning$i',
        ),
      for (var i = 0; i < customBookmarkedIds.length; i++)
        VocabMasterCompanion.insert(
          id: customBookmarkedIds[i],
          lemma: 'customLemma$i',
          meaning: 'customMeaning$i',
        ),
    ]);
    batch.insertAll(database.vocabUser, <VocabUserCompanion>[
      for (final customId in customBookmarkedIds)
        VocabUserCompanion.insert(
          vocabId: customId,
          isBookmarked: const Value(true),
        ),
    ]);
  });
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

String _quizSnapshot(VocabQuizQuestion question) {
  return '${question.vocabId}|${question.correctOptionIndex}|${question.options.join('||')}';
}
