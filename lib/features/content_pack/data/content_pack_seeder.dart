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
      await _insertPassages(seedPack);
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

  Future<void> _insertPassages(SeedContentPack seedPack) async {
    for (final passage in seedPack.passages) {
      await _database
          .into(_database.passages)
          .insertOnConflictUpdate(
            PassagesCompanion(
              id: Value(passage.id),
              packId: Value(seedPack.id),
              title: Value(passage.title),
              body: Value(passage.body),
              orderIndex: Value(passage.order),
              difficulty: Value(passage.difficulty),
            ),
          );

      for (final script in passage.scripts) {
        await _database
            .into(_database.scripts)
            .insertOnConflictUpdate(
              ScriptsCompanion(
                id: Value(script.id),
                passageId: Value(passage.id),
                speaker: Value(script.speaker),
                textBody: Value(script.text),
                orderIndex: Value(script.order),
              ),
            );
      }

      for (final question in passage.questions) {
        await _database
            .into(_database.questions)
            .insertOnConflictUpdate(
              QuestionsCompanion(
                id: Value(question.id),
                passageId: Value(passage.id),
                prompt: Value(question.prompt),
                questionType: Value(question.type),
                optionsJson: Value(
                  question.options == null
                      ? null
                      : jsonEncode(question.options),
                ),
                answerJson: Value(jsonEncode(question.answer)),
                orderIndex: Value(question.order),
              ),
            );

        for (final explanation in question.explanations) {
          await _database
              .into(_database.explanations)
              .insertOnConflictUpdate(
                ExplanationsCompanion(
                  id: Value(explanation.id),
                  questionId: Value(question.id),
                  body: Value(explanation.body),
                ),
              );
        }
      }
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
}
