import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/security/sha256_hash.dart';
import 'mock_exam_period_key.dart';

class MockExamQuestionPlan {
  const MockExamQuestionPlan({
    required this.listeningCount,
    required this.readingCount,
  });

  final int listeningCount;
  final int readingCount;

  int get plannedItems => listeningCount + readingCount;
}

class MockExamSessionBundle {
  const MockExamSessionBundle({
    required this.sessionId,
    required this.examType,
    required this.periodKey,
    required this.track,
    required this.plannedItems,
    required this.completedItems,
    required this.items,
  });

  final int sessionId;
  final MockExamType examType;
  final String periodKey;
  final String track;
  final int plannedItems;
  final int completedItems;
  final List<MockExamSessionItemBundle> items;
}

class MockExamSessionItemBundle {
  const MockExamSessionItemBundle({
    required this.orderIndex,
    required this.questionId,
    required this.skill,
  });

  final int orderIndex;
  final String questionId;
  final Skill skill;
}

class MockExamSessionRepository {
  const MockExamSessionRepository({required AppDatabase database})
    : _database = database;

  static const MockExamQuestionPlan weeklyDefaultPlan = MockExamQuestionPlan(
    listeningCount: 10,
    readingCount: 10,
  );
  static const MockExamQuestionPlan monthlyDefaultPlan = MockExamQuestionPlan(
    listeningCount: 17,
    readingCount: 28,
  );

  final AppDatabase _database;

  Future<MockExamSessionBundle> getOrCreateSession({
    required MockExamType type,
    required String track,
    required MockExamQuestionPlan plan,
    DateTime? nowLocal,
  }) async {
    trackFromDb(track);
    _validateQuestionPlan(plan);

    final resolvedNow = nowLocal ?? DateTime.now();
    final periodKey = buildMockExamPeriodKey(type: type, nowLocal: resolvedNow);
    validateMockExamPeriodKey(type: type, periodKey: periodKey);
    final examTypeDb = type.dbValue;

    return _database.transaction(() async {
      final existing = await _findSession(
        examType: examTypeDb,
        periodKey: periodKey,
        track: track,
      );
      if (existing != null) {
        final items = await _loadSessionItems(existing.id);
        return _toBundle(existing, items);
      }

      final listeningPool = await _loadQuestionPool(
        track: track,
        skill: Skill.listening,
      );
      final readingPool = await _loadQuestionPool(
        track: track,
        skill: Skill.reading,
      );

      final seed = '$examTypeDb|$periodKey|$track';
      final listeningIds = _pickQuestionIds(
        questionIds: listeningPool,
        count: plan.listeningCount,
        seed: '$seed|LISTENING',
        skill: Skill.listening,
      );
      final readingIds = _pickQuestionIds(
        questionIds: readingPool,
        count: plan.readingCount,
        seed: '$seed|READING',
        skill: Skill.reading,
      );
      final orderedQuestionIds = <String>[...listeningIds, ...readingIds];

      int sessionId;
      try {
        sessionId = await _database
            .into(_database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: examTypeDb,
                periodKey: periodKey,
                track: track,
                plannedItems: plan.plannedItems,
                completedItems: const Value(0),
              ),
            );
      } catch (error) {
        if (!_isSessionUniqueConflict(error)) {
          rethrow;
        }
        final concurrent = await _findSession(
          examType: examTypeDb,
          periodKey: periodKey,
          track: track,
        );
        if (concurrent == null) {
          rethrow;
        }
        final items = await _loadSessionItems(concurrent.id);
        return _toBundle(concurrent, items);
      }

      await _database.batch((batch) {
        for (var index = 0; index < orderedQuestionIds.length; index++) {
          batch.insert(
            _database.mockExamSessionItems,
            MockExamSessionItemsCompanion.insert(
              sessionId: sessionId,
              orderIndex: index,
              questionId: orderedQuestionIds[index],
            ),
          );
        }
      });

      final created = await _findSessionById(sessionId);
      if (created == null) {
        throw StateError('Created mock exam session not found: $sessionId');
      }
      final items = await _loadSessionItems(sessionId);
      return _toBundle(created, items);
    });
  }

  void _validateQuestionPlan(MockExamQuestionPlan plan) {
    if (plan.listeningCount < 0 || plan.readingCount < 0) {
      throw const FormatException('question plan counts must be >= 0');
    }
    if (plan.plannedItems <= 0) {
      throw const FormatException('question plan must include at least 1 item');
    }
  }

  Future<MockExamSession?> _findSession({
    required String examType,
    required String periodKey,
    required String track,
  }) {
    return (_database.select(_database.mockExamSessions)..where(
          (tbl) =>
              tbl.examType.equals(examType) &
              tbl.periodKey.equals(periodKey) &
              tbl.track.equals(track),
        ))
        .getSingleOrNull();
  }

  Future<MockExamSession?> _findSessionById(int sessionId) {
    return (_database.select(
      _database.mockExamSessions,
    )..where((tbl) => tbl.id.equals(sessionId))).getSingleOrNull();
  }

  Future<List<String>> _loadQuestionPool({
    required String track,
    required Skill skill,
  }) async {
    final rows =
        await (_database.select(_database.questions)..where(
              (tbl) =>
                  tbl.track.equals(track) & tbl.skill.equals(skill.dbValue),
            ))
            .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  List<String> _pickQuestionIds({
    required List<String> questionIds,
    required int count,
    required String seed,
    required Skill skill,
  }) {
    if (count == 0) {
      return const <String>[];
    }
    if (questionIds.length < count) {
      throw StateError(
        'INSUFFICIENT_QUESTIONS: skill=${skill.dbValue}, required=$count, actual=${questionIds.length}',
      );
    }

    final scored =
        <_ScoredQuestion>[
          for (final questionId in questionIds)
            _ScoredQuestion(
              questionId: questionId,
              score: computeSha256Hex('$seed|$questionId'),
            ),
        ]..sort((a, b) {
          final byScore = a.score.compareTo(b.score);
          if (byScore != 0) {
            return byScore;
          }
          return a.questionId.compareTo(b.questionId);
        });

    return scored
        .take(count)
        .map((entry) => entry.questionId)
        .toList(growable: false);
  }

  Future<List<MockExamSessionItemBundle>> _loadSessionItems(int sessionId) {
    return _database
        .customSelect(
          'SELECT msi.order_index AS order_index, '
          'msi.question_id AS question_id, '
          'q.skill AS skill '
          'FROM mock_exam_session_items msi '
          'INNER JOIN questions q ON q.id = msi.question_id '
          'WHERE msi.session_id = ? '
          'ORDER BY msi.order_index ASC',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {_database.mockExamSessionItems, _database.questions},
        )
        .map(
          (row) => MockExamSessionItemBundle(
            orderIndex: row.read<int>('order_index'),
            questionId: row.read<String>('question_id'),
            skill: skillFromDb(row.read<String>('skill')),
          ),
        )
        .get();
  }

  MockExamSessionBundle _toBundle(
    MockExamSession session,
    List<MockExamSessionItemBundle> items,
  ) {
    return MockExamSessionBundle(
      sessionId: session.id,
      examType: mockExamTypeFromDb(session.examType),
      periodKey: session.periodKey,
      track: session.track,
      plannedItems: session.plannedItems,
      completedItems: session.completedItems,
      items: items,
    );
  }

  bool _isSessionUniqueConflict(Object error) {
    final message = error.toString();
    return message.contains('2067') ||
        message.contains(
          'UNIQUE constraint failed: mock_exam_sessions.exam_type, mock_exam_sessions.period_key, mock_exam_sessions.track',
        ) ||
        message.contains('mock_exam_sessions.exam_type') ||
        message.contains('mock_exam_sessions.period_key') ||
        message.contains('mock_exam_sessions.track');
  }
}

class _ScoredQuestion {
  const _ScoredQuestion({required this.questionId, required this.score});

  final String questionId;
  final String score;
}
