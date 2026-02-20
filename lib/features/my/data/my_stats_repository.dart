import 'dart:math' as math;

import 'package:drift/drift.dart' show Variable;

import '../../../core/database/app_database.dart';
import '../../../core/time/day_key.dart';

class MyStatsSnapshot {
  const MyStatsSnapshot({
    required this.todayCompletedItems,
    required this.weeklyCompletedDays,
    required this.totalAttempts,
    required this.totalWrongAttempts,
  });

  final int todayCompletedItems;
  final int weeklyCompletedDays;
  final int totalAttempts;
  final int totalWrongAttempts;
}

class MyStatsRepository {
  const MyStatsRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<MyStatsSnapshot> load({
    required String track,
    DateTime? nowLocal,
  }) async {
    final resolvedNow = nowLocal ?? DateTime.now();
    final todayLocal = DateTime(
      resolvedNow.year,
      resolvedNow.month,
      resolvedNow.day,
    );
    final startOf7DaysLocal = todayLocal.subtract(const Duration(days: 6));

    final todayDayKey = int.parse(formatDayKey(todayLocal));
    final weekStartDayKey = int.parse(formatDayKey(startOf7DaysLocal));

    final todayCompletedItems = await _loadTodayCompletedItems(
      dayKey: todayDayKey,
      track: track,
    );
    final weeklyCompletedDays = await _loadWeeklyCompletedDays(
      startDayKey: weekStartDayKey,
      endDayKey: todayDayKey,
    );
    final totalAttempts = await _loadTotalAttempts();
    final totalWrongAttempts = await _loadTotalWrongAttempts();

    return MyStatsSnapshot(
      todayCompletedItems: todayCompletedItems,
      weeklyCompletedDays: weeklyCompletedDays,
      totalAttempts: totalAttempts,
      totalWrongAttempts: totalWrongAttempts,
    );
  }

  Future<int> _loadTodayCompletedItems({
    required int dayKey,
    required String track,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT completed_items '
          'FROM daily_sessions '
          'WHERE day_key = ? AND track = ? '
          'LIMIT 1',
          variables: <Variable<Object>>[
            Variable<int>(dayKey),
            Variable<String>(track),
          ],
          readsFrom: {_database.dailySessions},
        )
        .getSingleOrNull();
    final completedItems = row?.read<int>('completed_items') ?? 0;
    return completedItems.clamp(0, 6);
  }

  Future<int> _loadWeeklyCompletedDays({
    required int startDayKey,
    required int endDayKey,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(DISTINCT day_key) AS completed_days '
          'FROM daily_sessions '
          'WHERE day_key BETWEEN ? AND ? '
          'AND completed_items = 6',
          variables: <Variable<Object>>[
            Variable<int>(startDayKey),
            Variable<int>(endDayKey),
          ],
          readsFrom: {_database.dailySessions},
        )
        .getSingle();
    final rawCount = row.read<int>('completed_days');
    return math.min(rawCount, 7);
  }

  Future<int> _loadTotalAttempts() async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS total_attempts FROM attempts',
          readsFrom: {_database.attempts},
        )
        .getSingle();
    return row.read<int>('total_attempts');
  }

  Future<int> _loadTotalWrongAttempts() async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS total_wrong '
          'FROM attempts '
          'WHERE is_correct = 0',
          readsFrom: {_database.attempts},
        )
        .getSingle();
    return row.read<int>('total_wrong');
  }
}
