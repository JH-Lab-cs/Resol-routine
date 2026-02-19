import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/day_key.dart';

class DailySessionBundle {
  const DailySessionBundle({
    required this.sessionId,
    required this.dayKey,
    required this.track,
    required this.plannedItems,
    required this.completedItems,
    required this.items,
  });

  final int sessionId;
  final String dayKey;
  final String track;
  final int plannedItems;
  final int completedItems;
  final List<DailySessionItemBundle> items;
}

class DailySessionItemBundle {
  const DailySessionItemBundle({
    required this.orderIndex,
    required this.questionId,
    required this.skill,
  });

  final int orderIndex;
  final String questionId;
  final String skill;
}

class TodaySessionRepository {
  const TodaySessionRepository({required AppDatabase database})
    : _database = database;

  static const int _questionsPerSkill = 3;
  static const int _plannedItems = 6;
  static const Set<String> _supportedTracks = <String>{'M3', 'H1', 'H2', 'H3'};

  final AppDatabase _database;

  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) async {
    _validateTrack(track);

    final resolvedNow = nowLocal ?? DateTime.now();
    final dayKey = formatDayKey(resolvedNow);
    validateDayKey(dayKey);
    final dayKeyInt = int.parse(dayKey);

    return _database.transaction(() async {
      final existingSession = await _findSession(dayKeyInt, track);
      if (existingSession != null) {
        final existingItems = await _loadSessionItems(existingSession.id);
        return _toBundle(
          session: existingSession,
          dayKey: dayKey,
          items: existingItems,
        );
      }

      final questionIds = await _selectQuestionIds(
        dayKey: dayKey,
        track: track,
      );

      final sessionId = await _database
          .into(_database.dailySessions)
          .insert(
            DailySessionsCompanion.insert(
              dayKey: dayKeyInt,
              track: Value(track),
              plannedItems: const Value(_plannedItems),
              completedItems: const Value(0),
            ),
          );

      await _insertSessionItems(sessionId: sessionId, questionIds: questionIds);

      final createdSession = await _findSessionById(sessionId);
      if (createdSession == null) {
        throw StateError('Created daily session not found: $sessionId');
      }

      final createdItems = await _loadSessionItems(sessionId);
      return _toBundle(
        session: createdSession,
        dayKey: dayKey,
        items: createdItems,
      );
    });
  }

  Future<DailySession?> _findSession(int dayKey, String track) {
    return (_database.select(_database.dailySessions)
          ..where((tbl) => tbl.dayKey.equals(dayKey) & tbl.track.equals(track)))
        .getSingleOrNull();
  }

  Future<DailySession?> _findSessionById(int sessionId) {
    return (_database.select(
      _database.dailySessions,
    )..where((tbl) => tbl.id.equals(sessionId))).getSingleOrNull();
  }

  Future<void> _insertSessionItems({
    required int sessionId,
    required List<String> questionIds,
  }) async {
    await _database.batch((Batch b) {
      for (var index = 0; index < questionIds.length; index++) {
        b.insert(
          _database.dailySessionItems,
          DailySessionItemsCompanion.insert(
            sessionId: sessionId,
            orderIndex: index,
            questionId: questionIds[index],
          ),
        );
      }
    });
  }

  Future<List<String>> _selectQuestionIds({
    required String dayKey,
    required String track,
  }) async {
    final listeningPool = await _loadQuestionPool(
      skill: 'LISTENING',
      track: track,
    );
    final readingPool = await _loadQuestionPool(skill: 'READING', track: track);

    final listeningIds = _pickQuestionIds(
      dayKey: dayKey,
      track: track,
      skill: 'LISTENING',
      questionIds: listeningPool,
    );
    final readingIds = _pickQuestionIds(
      dayKey: dayKey,
      track: track,
      skill: 'READING',
      questionIds: readingPool,
    );

    return <String>[...listeningIds, ...readingIds];
  }

  Future<List<String>> _loadQuestionPool({
    required String skill,
    required String track,
  }) async {
    final rows = await (_database.select(
      _database.questions,
    )..where((tbl) => tbl.skill.equals(skill) & tbl.track.equals(track))).get();

    return rows.map((Question row) => row.id).toList(growable: false);
  }

  List<String> _pickQuestionIds({
    required String dayKey,
    required String track,
    required String skill,
    required List<String> questionIds,
  }) {
    final scored =
        <_ScoredQuestion>[
          for (final questionId in questionIds)
            _ScoredQuestion(
              questionId: questionId,
              score: _fnv1a32('$dayKey|$track|$skill|$questionId'),
            ),
        ]..sort((a, b) {
          final byScore = a.score.compareTo(b.score);
          if (byScore != 0) {
            return byScore;
          }
          return a.questionId.compareTo(b.questionId);
        });

    if (scored.isEmpty) {
      throw StateError('No $skill questions available for track "$track".');
    }

    if (scored.length >= _questionsPerSkill) {
      return scored
          .take(_questionsPerSkill)
          .map((q) => q.questionId)
          .toList(growable: false);
    }

    return List<String>.generate(
      _questionsPerSkill,
      (index) => scored[index % scored.length].questionId,
      growable: false,
    );
  }

  Future<List<DailySessionItemBundle>> _loadSessionItems(int sessionId) async {
    final rows = await _database
        .customSelect(
          'SELECT dsi.order_index AS order_index, '
          'dsi.question_id AS question_id, '
          'q.skill AS skill '
          'FROM daily_session_items AS dsi '
          'INNER JOIN questions AS q ON q.id = dsi.question_id '
          'WHERE dsi.session_id = ? '
          'ORDER BY dsi.order_index ASC',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {_database.dailySessionItems, _database.questions},
        )
        .get();

    return rows
        .map(
          (row) => DailySessionItemBundle(
            orderIndex: row.read<int>('order_index'),
            questionId: row.read<String>('question_id'),
            skill: row.read<String>('skill'),
          ),
        )
        .toList(growable: false);
  }

  DailySessionBundle _toBundle({
    required DailySession session,
    required String dayKey,
    required List<DailySessionItemBundle> items,
  }) {
    return DailySessionBundle(
      sessionId: session.id,
      dayKey: dayKey,
      track: session.track,
      plannedItems: session.plannedItems,
      completedItems: session.completedItems,
      items: items,
    );
  }

  void _validateTrack(String track) {
    if (!_supportedTracks.contains(track)) {
      throw FormatException('Unsupported track: "$track"');
    }
  }
}

class _ScoredQuestion {
  const _ScoredQuestion({required this.questionId, required this.score});

  final String questionId;
  final int score;
}

int _fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
