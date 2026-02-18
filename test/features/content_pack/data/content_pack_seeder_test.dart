import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';

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
      expect(await database.countPassages(), 1);
      expect(await database.countQuestions(), 1);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });

    test('does not duplicate records when called more than once', () async {
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );

      await seeder.seedOnFirstLaunch();
      await seeder.seedOnFirstLaunch();

      expect(await database.countContentPacks(), 1);
      expect(await database.countPassages(), 1);
      expect(await database.countQuestions(), 1);
      expect(await database.countVocabMaster(), 3);
      expect(await database.countVocabSrsState(), 3);
    });
  });
}
