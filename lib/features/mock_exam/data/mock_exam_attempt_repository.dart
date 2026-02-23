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
