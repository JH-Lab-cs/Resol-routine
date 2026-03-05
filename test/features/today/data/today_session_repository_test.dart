import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';

void main() {
  group('TodaySessionRepository', () {
    late AppDatabase database;
    late String starterPackJson;
    late TodaySessionRepository repository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      repository = TodaySessionRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'same dayKey and track returns identical items with six unique entries',
      () async {
        final nowLocal = DateTime(2026, 2, 19, 9, 30);

        final first = await repository.getOrCreateSession(
          track: 'M3',
          nowLocal: nowLocal,
        );
        final second = await repository.getOrCreateSession(
          track: 'M3',
          nowLocal: nowLocal,
        );

        final firstSignature = first.items
            .map((item) => '${item.orderIndex}:${item.questionId}')
            .toList(growable: false);
        final secondSignature = second.items
            .map((item) => '${item.orderIndex}:${item.questionId}')
            .toList(growable: false);

        expect(firstSignature, orderedEquals(secondSignature));
        expect(first.items, hasLength(6));
        expect(
          first.items.map((item) => item.questionId).toSet(),
          hasLength(6),
        );

        final row = await database
            .customSelect(
              'SELECT COUNT(*) AS item_count '
              'FROM daily_session_items WHERE session_id = ?',
              variables: [Variable<int>(first.sessionId)],
              readsFrom: {database.dailySessionItems},
            )
            .getSingle();
        expect(row.read<int>('item_count'), 6);
      },
    );

    test('order_index and skill order match [L, L, L, R, R, R]', () async {
      final bundle = await repository.getOrCreateSession(
        track: 'H1',
        nowLocal: DateTime(2026, 2, 19, 10, 0),
      );

      expect(
        bundle.items.map((item) => item.orderIndex).toList(growable: false),
        orderedEquals(<int>[0, 1, 2, 3, 4, 5]),
      );
      expect(
        bundle.items.map((item) => item.skill).toList(growable: false),
        orderedEquals(<String>[
          'LISTENING',
          'LISTENING',
          'LISTENING',
          'READING',
          'READING',
          'READING',
        ]),
      );
    });

    test(
      'scheduler remains deterministic across repeated runs in process',
      () async {
        final nowLocal = DateTime(2026, 2, 19, 12, 0);

        final first = await repository.getOrCreateSession(
          track: 'H2',
          nowLocal: nowLocal,
        );
        final firstQuestionIds = first.items
            .map((item) => item.questionId)
            .toList(growable: false);

        await (database.delete(
          database.dailySessions,
        )..where((tbl) => tbl.id.equals(first.sessionId))).go();

        final second = await repository.getOrCreateSession(
          track: 'H2',
          nowLocal: nowLocal,
        );
        final secondQuestionIds = second.items
            .map((item) => item.questionId)
            .toList(growable: false);

        expect(firstQuestionIds, orderedEquals(secondQuestionIds));
      },
    );
  });
}
