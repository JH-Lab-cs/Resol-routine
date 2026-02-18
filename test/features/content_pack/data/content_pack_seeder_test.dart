import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
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
      expect(await database.countScripts(), 1);
      expect(await database.countPassages(), 1);
      expect(await database.countQuestions(), 2);
      expect(await database.countExplanations(), 2);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });

    test('writes exam question fields and fixed A-E options', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();

      final rows = await database.select(database.questions).get();

      expect(rows.length, 2);

      final listening = rows.firstWhere(
        (row) => row.id == 'question_listening_001',
      );
      expect(listening.skill, 'LISTENING');
      expect(listening.typeTag, 'L1');
      expect(listening.track, 'M3');
      expect(listening.difficulty, 2);
      expect(listening.scriptId, 'script_listening_001');
      expect(listening.passageId, isNull);
      expect(listening.answerKey, 'B');

      final listeningOptions =
          jsonDecode(listening.optionsJson) as Map<String, Object?>;
      expect(listeningOptions.keys.toSet(), {'A', 'B', 'C', 'D', 'E'});

      final reading = rows.firstWhere(
        (row) => row.id == 'question_reading_001',
      );
      expect(reading.skill, 'READING');
      expect(reading.typeTag, 'R1');
      expect(reading.track, 'H1');
      expect(reading.difficulty, 2);
      expect(reading.passageId, 'passage_reading_001');
      expect(reading.scriptId, isNull);
      expect(reading.answerKey, 'A');

      final readingOptions =
          jsonDecode(reading.optionsJson) as Map<String, Object?>;
      expect(readingOptions.keys.toSet(), {'A', 'B', 'C', 'D', 'E'});
    });

    test('does not duplicate records when called more than once', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();
      await seeder.seedOnFirstLaunch();

      expect(await database.countContentPacks(), 1);
      expect(await database.countScripts(), 1);
      expect(await database.countPassages(), 1);
      expect(await database.countQuestions(), 2);
      expect(await database.countExplanations(), 2);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });

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
      final decoded = jsonDecode(starterPackJson) as Map<String, Object?>;
      final scripts = List<Object?>.from(decoded['scripts'] as List<Object?>);
      scripts.add(Map<String, Object?>.from(scripts.first! as JsonMap));
      decoded['scripts'] = scripts;

      final overLimitJson = jsonEncode(decoded);
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(overLimitJson),
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
