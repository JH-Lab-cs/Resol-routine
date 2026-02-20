import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/my/data/my_stats_repository.dart';

void main() {
  group('MyStatsRepository', () {
    late AppDatabase database;
    late MyStatsRepository repository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();
      repository = MyStatsRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'loads today, weekly, and attempt metrics from DB rows only',
      () async {
        await _insertSession(
          database,
          dayKey: 20260220,
          track: 'M3',
          completedItems: 4,
        );
        await _insertSession(
          database,
          dayKey: 20260219,
          track: 'M3',
          completedItems: 6,
        );
        await _insertSession(
          database,
          dayKey: 20260218,
          track: 'M3',
          completedItems: 6,
        );
        await _insertSession(
          database,
          dayKey: 20260218,
          track: 'H1',
          completedItems: 6,
        );
        await _insertSession(
          database,
          dayKey: 20260217,
          track: 'M3',
          completedItems: 5,
        );
        await _insertSession(
          database,
          dayKey: 20260213,
          track: 'M3',
          completedItems: 6,
        );

        final questionId = await _loadFirstQuestionId(database);
        await _insertAttempt(database, questionId: questionId, isCorrect: true);
        await _insertAttempt(
          database,
          questionId: questionId,
          isCorrect: false,
        );
        await _insertAttempt(database, questionId: questionId, isCorrect: true);
        await _insertAttempt(
          database,
          questionId: questionId,
          isCorrect: false,
        );

        final stats = await repository.load(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 20, 9, 0),
        );

        expect(stats.todayCompletedItems, 4);
        expect(stats.weeklyCompletedDays, 2);
        expect(stats.totalAttempts, 4);
        expect(stats.totalWrongAttempts, 2);
      },
    );
  });
}

Future<void> _insertSession(
  AppDatabase database, {
  required int dayKey,
  required String track,
  required int completedItems,
}) async {
  await database
      .into(database.dailySessions)
      .insert(
        DailySessionsCompanion.insert(
          dayKey: dayKey,
          track: Value(track),
          plannedItems: const Value(6),
          completedItems: Value(completedItems),
          createdAt: Value(DateTime.utc(2026, 2, 20, 0, 0)),
        ),
      );
}

Future<String> _loadFirstQuestionId(AppDatabase database) async {
  final row = await (database.select(database.questions)..limit(1)).getSingle();
  return row.id;
}

Future<void> _insertAttempt(
  AppDatabase database, {
  required String questionId,
  required bool isCorrect,
}) async {
  await database
      .into(database.attempts)
      .insert(
        AttemptsCompanion.insert(
          questionId: questionId,
          userAnswerJson: '{}',
          isCorrect: isCorrect,
          attemptedAt: Value(DateTime.utc(2026, 2, 20, 9, 0)),
        ),
      );
}
