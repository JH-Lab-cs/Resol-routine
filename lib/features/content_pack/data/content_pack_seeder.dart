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
  }) : _database = database,
       _source = source;

  final AppDatabase _database;
  final ContentPackSource _source;

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
      return SeedContentPack.parse(rawJson);
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
        .insertOnConflictUpdate(
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
    for (final script in seedPack.scripts) {
      final sentencePayload = [
        for (final sentence in script.sentences)
          {'id': sentence.id, 'text': sentence.text},
      ];
      final turnPayload = [
        for (final turn in script.turns)
          {'speaker': turn.speaker, 'sentenceIds': turn.sentenceIds},
      ];

      await _database
          .into(_database.scripts)
          .insertOnConflictUpdate(
            ScriptsCompanion(
              id: Value(script.id),
              packId: Value(seedPack.id),
              sentencesJson: Value(jsonEncode(sentencePayload)),
              turnsJson: Value(jsonEncode(turnPayload)),
              ttsPlanJson: Value(
                jsonEncode({
                  'repeatPolicy': script.ttsPlan.repeatPolicy,
                  'pauseRangeMs': script.ttsPlan.pauseRangeMs,
                  'rateRange': script.ttsPlan.rateRange,
                  'pitchRange': script.ttsPlan.pitchRange,
                  'voiceRoles': script.ttsPlan.voiceRoles,
                }),
              ),
              orderIndex: Value(script.order),
            ),
          );
    }
  }

  Future<void> _insertPassages(SeedContentPack seedPack) async {
    for (final passage in seedPack.passages) {
      final sentencePayload = [
        for (final sentence in passage.sentences)
          {'id': sentence.id, 'text': sentence.text},
      ];

      await _database
          .into(_database.passages)
          .insertOnConflictUpdate(
            PassagesCompanion(
              id: Value(passage.id),
              packId: Value(seedPack.id),
              title: Value(passage.title),
              sentencesJson: Value(jsonEncode(sentencePayload)),
              orderIndex: Value(passage.order),
            ),
          );
    }
  }

  Future<void> _insertQuestionsAndExplanations(SeedContentPack seedPack) async {
    for (final question in seedPack.questions) {
      await _database
          .into(_database.questions)
          .insertOnConflictUpdate(
            QuestionsCompanion(
              id: Value(question.id),
              skill: Value(question.skill),
              typeTag: Value(question.typeTag),
              track: Value(question.track),
              difficulty: Value(question.difficulty),
              passageId: Value(question.passageId),
              scriptId: Value(question.scriptId),
              prompt: Value(question.prompt),
              optionsJson: Value(jsonEncode(question.options)),
              answerKey: Value(question.answerKey),
              orderIndex: Value(question.order),
            ),
          );

      final explanation = question.explanation;
      await _database
          .into(_database.explanations)
          .insertOnConflictUpdate(
            ExplanationsCompanion(
              id: Value(explanation.id),
              questionId: Value(question.id),
              evidenceSentenceIdsJson: Value(
                jsonEncode(explanation.evidenceSentenceIds),
              ),
              whyCorrectKo: Value(explanation.whyCorrectKo),
              whyWrongKoJson: Value(jsonEncode(explanation.whyWrongKo)),
              vocabNotesJson: Value(
                _encodeNullableJson(explanation.vocabNotes),
              ),
              structureNotesKo: Value(explanation.structureNotesKo),
              glossKoJson: Value(_encodeNullableJson(explanation.glossKo)),
            ),
          );
    }
  }

  Future<void> _insertVocabulary(SeedContentPack seedPack) async {
    for (final vocab in seedPack.vocabulary) {
      await _database
          .into(_database.vocabMaster)
          .insertOnConflictUpdate(
            VocabMasterCompanion(
              id: Value(vocab.id),
              lemma: Value(vocab.lemma),
              pos: Value(vocab.partOfSpeech),
              meaning: Value(vocab.meaning),
              example: Value(vocab.example),
              ipa: Value(vocab.ipa),
            ),
          );

      await _database
          .into(_database.vocabUser)
          .insert(
            VocabUserCompanion(
              vocabId: Value(vocab.id),
              familiarity: const Value(0),
              isBookmarked: const Value(false),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      await _database
          .into(_database.vocabSrsState)
          .insert(
            VocabSrsStateCompanion(
              vocabId: Value(vocab.id),
              dueAt: Value(DateTime.now().toUtc()),
              intervalDays: const Value(1),
              easeFactor: const Value(2.5),
              repetition: const Value(0),
              lapses: const Value(0),
              suspended: const Value(false),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  String? _encodeNullableJson(Object? value) {
    if (value == null) {
      return null;
    }

    return jsonEncode(value);
  }
}
