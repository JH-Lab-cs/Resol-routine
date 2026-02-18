import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';
import 'models/content_pack_seed.dart';

abstract class ContentPackSource {
  Future<String> load();
}

class AssetContentPackSource implements ContentPackSource {
  const AssetContentPackSource(this.assetPath, {AssetBundle? assetBundle})
    : _assetBundle = assetBundle;

  final String assetPath;
  final AssetBundle? _assetBundle;

  @override
  Future<String> load() {
    final bundle = _assetBundle ?? rootBundle;
    return bundle.loadString(assetPath);
  }
}

class MemoryContentPackSource implements ContentPackSource {
  const MemoryContentPackSource(this.rawJson);

  final String rawJson;

  @override
  Future<String> load() async => rawJson;
}

class ContentPackSeeder {
  const ContentPackSeeder({
    required AppDatabase database,
    required ContentPackSource source,
    this.limits = const SeedLimits(),
    this.insertChunkSize = 500,
  }) : _database = database,
       _source = source,
       assert(insertChunkSize > 0);

  final AppDatabase _database;
  final ContentPackSource _source;
  final SeedLimits limits;
  final int insertChunkSize;

  Future<void> seedOnFirstLaunch() async {
    if (await _database.hasAnyContentPacks()) {
      return;
    }

    final seedPack = await _loadAndValidate();

    await _database.transaction(() async {
      if (await _database.hasAnyContentPacks()) {
        return;
      }

      await _insertPack(seedPack);
      await _insertScripts(seedPack);
      await _insertPassages(seedPack);
      await _insertQuestionsAndExplanations(seedPack);
      await _insertVocabulary(seedPack);
    });
  }

  Future<SeedContentPack> _loadAndValidate() async {
    try {
      final rawJson = await _source.load();
      return SeedContentPack.parse(rawJson, limits: limits);
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Content pack JSON failed validation.',
        name: 'ContentPackSeeder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Content pack loading failed.',
        name: 'ContentPackSeeder',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _insertPack(SeedContentPack seedPack) async {
    await _database
        .into(_database.contentPacks)
        .insert(
          ContentPacksCompanion(
            id: Value(seedPack.id),
            version: Value(seedPack.version),
            locale: Value(seedPack.locale),
            title: Value(seedPack.title),
            description: Value(seedPack.description),
            checksum: Value(seedPack.checksum),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _insertScripts(SeedContentPack seedPack) async {
    final rows = <Insertable<Script>>[
      for (final script in seedPack.scripts)
        ScriptsCompanion(
          id: Value(script.id),
          packId: Value(seedPack.id),
          sentencesJson: Value(script.sentences),
          turnsJson: Value(script.turns),
          ttsPlanJson: Value(script.ttsPlan),
          orderIndex: Value(script.order),
        ),
    ];

    await _insertAllChunked(_database.scripts, rows);
  }

  Future<void> _insertPassages(SeedContentPack seedPack) async {
    final rows = <Insertable<Passage>>[
      for (final passage in seedPack.passages)
        PassagesCompanion(
          id: Value(passage.id),
          packId: Value(seedPack.id),
          title: Value(passage.title),
          sentencesJson: Value(passage.sentences),
          orderIndex: Value(passage.order),
        ),
    ];

    await _insertAllChunked(_database.passages, rows);
  }

  Future<void> _insertQuestionsAndExplanations(SeedContentPack seedPack) async {
    final questionRows = <Insertable<Question>>[
      for (final question in seedPack.questions)
        QuestionsCompanion(
          id: Value(question.id),
          skill: Value(question.skill),
          typeTag: Value(question.typeTag),
          track: Value(question.track),
          difficulty: Value(question.difficulty),
          passageId: Value(question.passageId),
          scriptId: Value(question.scriptId),
          prompt: Value(question.prompt),
          optionsJson: Value(question.options),
          answerKey: Value(question.answerKey),
          orderIndex: Value(question.order),
        ),
    ];

    await _insertAllChunked(_database.questions, questionRows);

    final explanationRows = <Insertable<Explanation>>[
      for (final question in seedPack.questions)
        ExplanationsCompanion(
          id: Value(question.explanation.id),
          questionId: Value(question.id),
          evidenceSentenceIdsJson: Value(
            question.explanation.evidenceSentenceIds,
          ),
          whyCorrectKo: Value(question.explanation.whyCorrectKo),
          whyWrongKoJson: Value(question.explanation.whyWrongKo),
          vocabNotesJson: Value(
            _encodeNullableJson(question.explanation.vocabNotes),
          ),
          structureNotesKo: Value(question.explanation.structureNotesKo),
          glossKoJson: Value(_encodeNullableJson(question.explanation.glossKo)),
        ),
    ];

    await _insertAllChunked(_database.explanations, explanationRows);
  }

  Future<void> _insertVocabulary(SeedContentPack seedPack) async {
    final vocabMasterRows = <Insertable<VocabMasterData>>[
      for (final vocab in seedPack.vocabulary)
        VocabMasterCompanion(
          id: Value(vocab.id),
          lemma: Value(vocab.lemma),
          pos: Value(vocab.partOfSpeech),
          meaning: Value(vocab.meaning),
          example: Value(vocab.example),
          ipa: Value(vocab.ipa),
        ),
    ];
    await _insertAllChunked(_database.vocabMaster, vocabMasterRows);

    final now = DateTime.now().toUtc();
    final vocabUserRows = <Insertable<VocabUserData>>[
      for (final vocab in seedPack.vocabulary)
        VocabUserCompanion(
          vocabId: Value(vocab.id),
          familiarity: const Value(0),
          isBookmarked: const Value(false),
          updatedAt: Value(now),
        ),
    ];
    await _insertAllChunked(_database.vocabUser, vocabUserRows);

    final vocabSrsRows = <Insertable<VocabSrsStateData>>[
      for (final vocab in seedPack.vocabulary)
        VocabSrsStateCompanion(
          vocabId: Value(vocab.id),
          dueAt: Value(now),
          intervalDays: const Value(1),
          easeFactor: const Value(2.5),
          repetition: const Value(0),
          lapses: const Value(0),
          suspended: const Value(false),
          updatedAt: Value(now),
        ),
    ];
    await _insertAllChunked(_database.vocabSrsState, vocabSrsRows);
  }

  Future<void> _insertAllChunked<T extends Table, D>(
    TableInfo<T, D> table,
    List<Insertable<D>> rows,
  ) async {
    if (rows.isEmpty) {
      return;
    }

    for (var start = 0; start < rows.length; start += insertChunkSize) {
      final end = (start + insertChunkSize > rows.length)
          ? rows.length
          : start + insertChunkSize;
      final chunk = rows.sublist(start, end);
      await _database.batch((Batch b) {
        b.insertAll(table, chunk);
      });
    }
  }

  String? _encodeNullableJson(Object? value) {
    if (value == null) {
      return null;
    }
    return jsonEncode(value);
  }
}
