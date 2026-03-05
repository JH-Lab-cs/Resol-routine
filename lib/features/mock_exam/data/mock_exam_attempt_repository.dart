import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/domain_enums.dart';
import '../../today/data/attempt_payload.dart';

class MockExamCompletionReport {
  const MockExamCompletionReport({
    required this.listeningCorrectCount,
    required this.readingCorrectCount,
    required this.wrongCount,
    required this.topWrongReasonTag,
  });

  final int listeningCorrectCount;
  final int readingCorrectCount;
  final int wrongCount;
  final WrongReasonTag? topWrongReasonTag;
}

class MockExamSessionProgress {
  const MockExamSessionProgress({
    required this.completed,
    required this.listeningCompleted,
    required this.readingCompleted,
  });

  final int completed;
  final int listeningCompleted;
  final int readingCompleted;
}

class MockExamResultSummary {
  const MockExamResultSummary({
    required this.sessionId,
    required this.examType,
    required this.periodKey,
    required this.track,
    required this.plannedItems,
    required this.completedItems,
    required this.listeningCorrectCount,
    required this.readingCorrectCount,
    required this.wrongCount,
    required this.topWrongReasonTag,
    required this.elapsed,
  });

  final int sessionId;
  final MockExamType examType;
  final String periodKey;
  final Track track;
  final int plannedItems;
  final int completedItems;
  final int listeningCorrectCount;
  final int readingCorrectCount;
  final int wrongCount;
  final WrongReasonTag? topWrongReasonTag;
  final Duration? elapsed;
}

class MockReviewItem {
  const MockReviewItem({
    required this.orderIndex,
    required this.questionId,
    required this.skill,
    required this.typeTag,
    required this.attemptId,
    required this.isAnswered,
    required this.isCorrect,
  });

  final int orderIndex;
  final String questionId;
  final Skill skill;
  final String typeTag;
  final int? attemptId;
  final bool isAnswered;
  final bool isCorrect;
}

class MockWrongItem {
  const MockWrongItem({
    required this.attemptId,
    required this.orderIndex,
    required this.questionId,
    required this.skill,
    required this.typeTag,
  });

  final int attemptId;
  final int orderIndex;
  final String questionId;
  final Skill skill;
  final String typeTag;
}

class MockExamAttemptRepository {
  const MockExamAttemptRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<void> saveAttemptIdempotent({
    required int mockSessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    WrongReasonTag? wrongReasonTag,
  }) async {
    _validateSelectedAnswer(selectedAnswer);

    if (!isCorrect) {
      if (wrongReasonTag == null || !wrongReasonTags.contains(wrongReasonTag)) {
        throw StateError('wrongReasonTag is required for incorrect attempts.');
      }
    } else {
      wrongReasonTag = null;
    }

    final payload = AttemptPayload(
      selectedAnswer: selectedAnswer,
      wrongReasonTag: wrongReasonTag,
    );
    final nowUtc = DateTime.now().toUtc();

    await _database.transaction(() async {
      final existingAttemptId = await _findMockSessionAttemptId(
        mockSessionId: mockSessionId,
        questionId: questionId,
      );

      if (existingAttemptId != null) {
        await _updateAttemptRow(
          attemptId: existingAttemptId,
          payload: payload,
          isCorrect: isCorrect,
          attemptedAt: nowUtc,
        );
      } else {
        try {
          await _database
              .into(_database.attempts)
              .insert(
                AttemptsCompanion.insert(
                  questionId: questionId,
                  sessionId: const Value(null),
                  mockSessionId: Value(mockSessionId),
                  userAnswerJson: payload.encode(),
                  isCorrect: isCorrect,
                  attemptedAt: Value(nowUtc),
                ),
              );
        } catch (error) {
          if (!_isMockSessionQuestionUniqueConflict(error)) {
            rethrow;
          }

          final conflictedAttemptId = await _findMockSessionAttemptId(
            mockSessionId: mockSessionId,
            questionId: questionId,
          );
          if (conflictedAttemptId == null) {
            rethrow;
          }

          await _updateAttemptRow(
            attemptId: conflictedAttemptId,
            payload: payload,
            isCorrect: isCorrect,
            attemptedAt: nowUtc,
          );
        }
      }

      await _syncCompletedItems(mockSessionId: mockSessionId);
    });
  }

  Future<int> findFirstUnansweredOrderIndex({
    required int mockSessionId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT msi.order_index AS order_index '
          'FROM mock_exam_session_items msi '
          'LEFT JOIN attempts a '
          '  ON a.mock_session_id = msi.session_id '
          ' AND a.question_id = msi.question_id '
          'WHERE msi.session_id = ? AND a.id IS NULL '
          'ORDER BY msi.order_index ASC '
          'LIMIT 1',
          variables: <Variable<Object>>[Variable<int>(mockSessionId)],
          readsFrom: {_database.mockExamSessionItems, _database.attempts},
        )
        .getSingleOrNull();

    if (row != null) {
      return row.read<int>('order_index');
    }

    final session = await (_database.select(
      _database.mockExamSessions,
    )..where((tbl) => tbl.id.equals(mockSessionId))).getSingle();
    return session.plannedItems;
  }

  Future<MockExamSessionProgress> loadSessionProgress(int mockSessionId) async {
    final summaryRows = await _database
        .customSelect(
          'SELECT '
          'COUNT(*) AS completed, '
          'SUM(CASE WHEN q.skill = \'LISTENING\' THEN 1 ELSE 0 END) AS listening_completed, '
          'SUM(CASE WHEN q.skill = \'READING\' THEN 1 ELSE 0 END) AS reading_completed '
          'FROM attempts a '
          'INNER JOIN questions q ON q.id = a.question_id '
          'WHERE a.mock_session_id = ?',
          variables: <Variable<Object>>[Variable<int>(mockSessionId)],
          readsFrom: {_database.attempts, _database.questions},
        )
        .getSingle();

    return MockExamSessionProgress(
      completed: summaryRows.read<int?>('completed') ?? 0,
      listeningCompleted: summaryRows.read<int?>('listening_completed') ?? 0,
      readingCompleted: summaryRows.read<int?>('reading_completed') ?? 0,
    );
  }

  Future<MockExamCompletionReport> loadCompletionReport(
    int mockSessionId,
  ) async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'q.skill AS skill, '
          'a.is_correct AS is_correct, '
          'a.user_answer_json AS user_answer_json '
          'FROM mock_exam_session_items msi '
          'INNER JOIN questions q ON q.id = msi.question_id '
          'LEFT JOIN attempts a '
          '  ON a.mock_session_id = msi.session_id '
          ' AND a.question_id = msi.question_id '
          'WHERE msi.session_id = ? '
          'ORDER BY msi.order_index ASC',
          variables: <Variable<Object>>[Variable<int>(mockSessionId)],
          readsFrom: {
            _database.mockExamSessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .get();

    var listeningCorrectCount = 0;
    var readingCorrectCount = 0;
    var wrongCount = 0;
    final wrongReasonCounts = <WrongReasonTag, int>{};

    for (final row in rows) {
      final isCorrect = _sqliteBoolOrNull(row.read<int?>('is_correct'));
      if (isCorrect == null) {
        continue;
      }

      final skill = skillFromDb(row.read<String>('skill'));
      if (isCorrect) {
        if (skill == Skill.listening) {
          listeningCorrectCount += 1;
        } else if (skill == Skill.reading) {
          readingCorrectCount += 1;
        }
        continue;
      }

      wrongCount += 1;
      final payloadRaw = row.read<String?>('user_answer_json');
      if (payloadRaw == null || payloadRaw.isEmpty) {
        continue;
      }

      final payload = AttemptPayload.decode(payloadRaw);
      final tag = payload.wrongReasonTag;
      if (tag == null) {
        continue;
      }
      wrongReasonCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
    }

    WrongReasonTag? topWrongReasonTag;
    var topCount = 0;
    for (final tag in WrongReasonTag.values) {
      final count = wrongReasonCounts[tag] ?? 0;
      if (count > topCount) {
        topCount = count;
        topWrongReasonTag = tag;
      }
    }

    return MockExamCompletionReport(
      listeningCorrectCount: listeningCorrectCount,
      readingCorrectCount: readingCorrectCount,
      wrongCount: wrongCount,
      topWrongReasonTag: topWrongReasonTag,
    );
  }

  Future<MockExamResultSummary> loadResultSummary({
    required int sessionId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT '
          'mes.id AS session_id, '
          'mes.exam_type AS exam_type, '
          'mes.period_key AS period_key, '
          'mes.track AS track, '
          'mes.planned_items AS planned_items, '
          'mes.completed_items AS completed_items, '
          'SUM(CASE WHEN q.skill = \'LISTENING\' AND a.is_correct = 1 THEN 1 ELSE 0 END) AS listening_correct_count, '
          'SUM(CASE WHEN q.skill = \'READING\' AND a.is_correct = 1 THEN 1 ELSE 0 END) AS reading_correct_count, '
          'SUM(CASE WHEN a.is_correct = 0 THEN 1 ELSE 0 END) AS wrong_count, '
          'MIN(a.attempted_at) AS first_attempted_at, '
          'MAX(a.attempted_at) AS last_attempted_at '
          'FROM mock_exam_sessions mes '
          'LEFT JOIN mock_exam_session_items msi ON msi.session_id = mes.id '
          'LEFT JOIN questions q ON q.id = msi.question_id '
          'LEFT JOIN attempts a '
          '  ON a.mock_session_id = mes.id '
          ' AND a.question_id = msi.question_id '
          'WHERE mes.id = ? '
          'GROUP BY '
          'mes.id, mes.exam_type, mes.period_key, mes.track, mes.planned_items, mes.completed_items',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {
            _database.mockExamSessions,
            _database.mockExamSessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .getSingleOrNull();

    if (row == null) {
      throw StateError('Mock session not found: $sessionId');
    }

    final firstAttemptedAt = row.read<DateTime?>('first_attempted_at');
    final lastAttemptedAt = row.read<DateTime?>('last_attempted_at');
    final elapsed = firstAttemptedAt != null && lastAttemptedAt != null
        ? lastAttemptedAt.difference(firstAttemptedAt)
        : null;
    final topWrongReasonTag = await _loadTopWrongReasonTag(
      sessionId: sessionId,
    );

    return MockExamResultSummary(
      sessionId: row.read<int>('session_id'),
      examType: mockExamTypeFromDb(row.read<String>('exam_type')),
      periodKey: row.read<String>('period_key'),
      track: trackFromDb(row.read<String>('track')),
      plannedItems: row.read<int>('planned_items'),
      completedItems: row.read<int>('completed_items'),
      listeningCorrectCount: row.read<int?>('listening_correct_count') ?? 0,
      readingCorrectCount: row.read<int?>('reading_correct_count') ?? 0,
      wrongCount: row.read<int?>('wrong_count') ?? 0,
      topWrongReasonTag: topWrongReasonTag,
      elapsed: elapsed,
    );
  }

  Future<List<MockReviewItem>> listReviewItems({required int sessionId}) async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'msi.order_index AS order_index, '
          'msi.question_id AS question_id, '
          'q.skill AS skill, '
          'q.type_tag AS type_tag, '
          'a.id AS attempt_id, '
          'a.is_correct AS is_correct '
          'FROM mock_exam_session_items msi '
          'INNER JOIN questions q ON q.id = msi.question_id '
          'LEFT JOIN attempts a '
          '  ON a.mock_session_id = msi.session_id '
          ' AND a.question_id = msi.question_id '
          'WHERE msi.session_id = ? '
          'ORDER BY msi.order_index ASC',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {
            _database.mockExamSessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .get();

    return rows
        .map((row) {
          final attemptId = row.read<int?>('attempt_id');
          final isCorrectRaw = row.read<int?>('is_correct');
          return MockReviewItem(
            orderIndex: row.read<int>('order_index'),
            questionId: row.read<String>('question_id'),
            skill: skillFromDb(row.read<String>('skill')),
            typeTag: row.read<String>('type_tag'),
            attemptId: attemptId,
            isAnswered: attemptId != null,
            isCorrect: isCorrectRaw == 1,
          );
        })
        .toList(growable: false);
  }

  Future<List<MockWrongItem>> listWrongItems({required int sessionId}) async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'a.id AS attempt_id, '
          'msi.order_index AS order_index, '
          'msi.question_id AS question_id, '
          'q.skill AS skill, '
          'q.type_tag AS type_tag '
          'FROM mock_exam_session_items msi '
          'INNER JOIN questions q ON q.id = msi.question_id '
          'INNER JOIN attempts a '
          '  ON a.mock_session_id = msi.session_id '
          ' AND a.question_id = msi.question_id '
          'WHERE msi.session_id = ? AND a.is_correct = 0 '
          'ORDER BY msi.order_index ASC',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {
            _database.mockExamSessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .get();

    return rows
        .map(
          (row) => MockWrongItem(
            attemptId: row.read<int>('attempt_id'),
            orderIndex: row.read<int>('order_index'),
            questionId: row.read<String>('question_id'),
            skill: skillFromDb(row.read<String>('skill')),
            typeTag: row.read<String>('type_tag'),
          ),
        )
        .toList(growable: false);
  }

  void _validateSelectedAnswer(String selectedAnswer) {
    switch (selectedAnswer) {
      case 'A':
      case 'B':
      case 'C':
      case 'D':
      case 'E':
        return;
      default:
        throw StateError('selectedAnswer must be one of A..E');
    }
  }

  Future<int?> _findMockSessionAttemptId({
    required int mockSessionId,
    required String questionId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT id '
          'FROM attempts '
          'WHERE mock_session_id = ? AND question_id = ? '
          'LIMIT 1',
          variables: <Variable<Object>>[
            Variable<int>(mockSessionId),
            Variable<String>(questionId),
          ],
          readsFrom: {_database.attempts},
        )
        .getSingleOrNull();

    return row?.read<int>('id');
  }

  Future<void> _updateAttemptRow({
    required int attemptId,
    required AttemptPayload payload,
    required bool isCorrect,
    required DateTime attemptedAt,
  }) {
    return (_database.update(
      _database.attempts,
    )..where((tbl) => tbl.id.equals(attemptId))).write(
      AttemptsCompanion(
        userAnswerJson: Value(payload.encode()),
        isCorrect: Value(isCorrect),
        attemptedAt: Value(attemptedAt),
      ),
    );
  }

  Future<void> _syncCompletedItems({required int mockSessionId}) async {
    final session = await (_database.select(
      _database.mockExamSessions,
    )..where((tbl) => tbl.id.equals(mockSessionId))).getSingleOrNull();
    if (session == null) {
      throw StateError('Mock session not found: $mockSessionId');
    }

    final countRow = await _database
        .customSelect(
          'SELECT COUNT(*) AS count FROM attempts WHERE mock_session_id = ?',
          variables: <Variable<Object>>[Variable<int>(mockSessionId)],
          readsFrom: {_database.attempts},
        )
        .getSingle();
    final answeredCount = countRow.read<int>('count');
    final completedItems = answeredCount > session.plannedItems
        ? session.plannedItems
        : answeredCount;
    final nowUtc = DateTime.now().toUtc();
    final completedAt = completedItems >= session.plannedItems
        ? (session.completedAt ?? nowUtc)
        : null;

    await (_database.update(
      _database.mockExamSessions,
    )..where((tbl) => tbl.id.equals(mockSessionId))).write(
      MockExamSessionsCompanion(
        completedItems: Value(completedItems),
        updatedAt: Value(nowUtc),
        completedAt: Value(completedAt),
      ),
    );
  }

  Future<WrongReasonTag?> _loadTopWrongReasonTag({
    required int sessionId,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT user_answer_json '
          'FROM attempts '
          'WHERE mock_session_id = ? AND is_correct = 0',
          variables: <Variable<Object>>[Variable<int>(sessionId)],
          readsFrom: {_database.attempts},
        )
        .get();

    final wrongReasonCounts = <WrongReasonTag, int>{};
    for (final row in rows) {
      final payload = AttemptPayload.decode(
        row.read<String>('user_answer_json'),
      );
      final tag = payload.wrongReasonTag;
      if (tag == null) {
        continue;
      }
      wrongReasonCounts.update(tag, (value) => value + 1, ifAbsent: () => 1);
    }

    WrongReasonTag? topWrongReasonTag;
    var topCount = 0;
    for (final tag in WrongReasonTag.values) {
      final count = wrongReasonCounts[tag] ?? 0;
      if (count > topCount) {
        topCount = count;
        topWrongReasonTag = tag;
      }
    }
    return topWrongReasonTag;
  }

  bool _isMockSessionQuestionUniqueConflict(Object error) {
    final message = error.toString();
    return message.contains('2067') ||
        message.contains('ux_attempts_mock_session_question') ||
        message.contains(
          'UNIQUE constraint failed: attempts.mock_session_id, attempts.question_id',
        ) ||
        message.contains('attempts.mock_session_id, attempts.question_id');
  }

  bool? _sqliteBoolOrNull(int? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue == 1) {
      return true;
    }
    if (rawValue == 0) {
      return false;
    }
    return null;
  }
}
