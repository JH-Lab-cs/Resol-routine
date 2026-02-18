import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/db_text_limits.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/content_pack/data/models/content_pack_seed.dart';

void main() {
  group('ContentPackSeeder', () {
    late AppDatabase database;
    late String starterPackJson;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
    });

    tearDown(() async {
      await database.close();
    });

    test('seeds content pack data into all required tables', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();

      expect(await database.countContentPacks(), 1);
      expect(await database.countScripts(), 12);
      expect(await database.countPassages(), 12);
      expect(await database.countQuestions(), 24);
      expect(await database.countExplanations(), 24);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });

    test('writes typed JSON columns for quiz and content data', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();

      final rows = await database.select(database.questions).get();
      expect(rows.length, 24);

      final listening = rows.firstWhere(
        (row) => row.id == 'question_listening_001',
      );
      expect(listening.skill, 'LISTENING');
      expect(listening.optionsJson, isA<OptionMap>());
      expect(listening.optionsJson.byKey('B'), 'Strawberries');
      expect(listening.answerKey, 'B');

      final reading = rows.firstWhere(
        (row) => row.id == 'question_reading_001',
      );
      expect(reading.skill, 'READING');
      expect(
        reading.optionsJson.byKey('A'),
        'Gloves and a reusable water bottle',
      );
      expect(reading.answerKey, 'A');

      final script = await (database.select(
        database.scripts,
      )..where((tbl) => tbl.id.equals('script_listening_001'))).getSingle();
      expect(script.sentencesJson.first.id, 'ls_001');
      expect(script.turnsJson.first.speaker, 'S1');
      expect(script.ttsPlanJson.pitchRange.min, greaterThanOrEqualTo(0.0));

      final explanations = await database.select(database.explanations).get();
      final listeningExplanation = explanations.firstWhere(
        (row) => row.id == 'explanation_listening_001',
      );
      expect(listeningExplanation.whyWrongKoJson.byKey('A'), isNotEmpty);
      expect(listeningExplanation.evidenceSentenceIdsJson, contains('ls_002'));
    });

    test('does not duplicate records when called more than once', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();
      await seeder.seedOnFirstLaunch();

      expect(await database.countContentPacks(), 1);
      expect(await database.countScripts(), 12);
      expect(await database.countPassages(), 12);
      expect(await database.countQuestions(), 24);
      expect(await database.countExplanations(), 24);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });

    test(
      'starter pack provides at least 3 listening and 3 reading per track',
      () async {
        final seeder = ContentPackSeeder(
          database: database,
          source: MemoryContentPackSource(starterPackJson),
        );

        await seeder.seedOnFirstLaunch();

        final rows = await database.select(database.questions).get();
        const tracks = <String>{'M3', 'H1', 'H2', 'H3'};

        for (final track in tracks) {
          final listeningCount = rows
              .where((row) => row.track == track && row.skill == 'LISTENING')
              .length;
          final readingCount = rows
              .where((row) => row.track == track && row.skill == 'READING')
              .length;

          expect(
            listeningCount,
            greaterThanOrEqualTo(3),
            reason: 'Expected >= 3 LISTENING questions for $track.',
          );
          expect(
            readingCount,
            greaterThanOrEqualTo(3),
            reason: 'Expected >= 3 READING questions for $track.',
          );
        }
      },
    );

    test('rejects unsupported skill values in seed questions', () async {
      final invalidJson = starterPackJson.replaceFirst(
        '"skill": "LISTENING"',
        '"skill": "VOCAB"',
      );

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(invalidJson),
      );

      expect(() => seeder.seedOnFirstLaunch(), throwsA(isA<FormatException>()));
    });

    test('rejects scripts length over injected maxScripts limit', () async {
      final decoded = _decodePack(starterPackJson);
      final scripts = List<Object?>.from(decoded['scripts']! as List<Object?>);
      scripts.add(jsonDecode(jsonEncode(scripts.first)) as Object?);
      decoded['scripts'] = scripts;

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(jsonEncode(decoded)),
        limits: const SeedLimits(maxScripts: 1),
      );

      expect(
        () => seeder.seedOnFirstLaunch(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('maxScripts'),
          ),
        ),
      );
    });

    test('rejects option text over injected maxOptionTextLen limit', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
        limits: const SeedLimits(maxOptionTextLen: 5),
      );

      expect(
        () => seeder.seedOnFirstLaunch(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('options'),
          ),
        ),
      );
    });

    test('rejects title longer than DB text limit', () async {
      final decoded = _decodePack(starterPackJson);
      final pack = Map<String, Object?>.from(
        decoded['pack']! as Map<String, Object?>,
      );
      pack['title'] = 'T' * (DbTextLimits.titleMax + 1);
      decoded['pack'] = pack;

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(jsonEncode(decoded)),
      );

      expect(
        () => seeder.seedOnFirstLaunch(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('pack.title'),
          ),
        ),
      );
    });

    test('rejects prompt longer than DB text limit', () async {
      final decoded = _decodePack(starterPackJson);
      final questions = List<Object?>.from(
        decoded['questions']! as List<Object?>,
      );
      final firstQuestion = Map<String, Object?>.from(
        questions.first! as Map<String, Object?>,
      );
      firstQuestion['prompt'] = 'P' * (DbTextLimits.promptMax + 1);
      questions[0] = firstQuestion;
      decoded['questions'] = questions;

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(jsonEncode(decoded)),
      );

      expect(
        () => seeder.seedOnFirstLaunch(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('questions[0].prompt'),
          ),
        ),
      );
    });

    test('enforces unique dayKey for daily sessions', () async {
      await database
          .into(database.dailySessions)
          .insert(DailySessionsCompanion.insert(dayKey: 20260218));

      expect(
        () => database
            .into(database.dailySessions)
            .insert(DailySessionsCompanion.insert(dayKey: 20260218)),
        throwsA(isA<Object>()),
      );
    });
  });
}

Map<String, Object?> _decodePack(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Expected root JSON object.');
  }
  return decoded;
}
