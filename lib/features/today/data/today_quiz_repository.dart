import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters/json_models.dart';
import '../../../core/time/day_key.dart';
import 'attempt_payload.dart';

class SessionProgress {
  const SessionProgress({
    required this.completed,
    required this.listeningCompleted,
    required this.readingCompleted,
  });

  final int completed;
  final int listeningCompleted;
  final int readingCompleted;
}

class SessionCompletionReport {
  const SessionCompletionReport({
    required this.listeningCorrectCount,
    required this.readingCorrectCount,
    required this.wrongCount,
    required this.topWrongReasonTag,
  });

  final int listeningCorrectCount;
  final int readingCorrectCount;
  final int wrongCount;
  final String? topWrongReasonTag;
}

class SourceLine {
  const SourceLine({
    required this.sentenceIds,
    required this.text,
    required this.index,
    this.speaker,
  });

  final List<String> sentenceIds;
  final String text;
  final int index;
  final String? speaker;

  bool containsEvidence(Set<String> evidenceIds) {
    for (final sentenceId in sentenceIds) {
      if (evidenceIds.contains(sentenceId)) {
        return true;
      }
    }
    return false;
  }
}

class QuizQuestionDetail {
  const QuizQuestionDetail({
    required this.orderIndex,
    required this.questionId,
    required this.skill,
    required this.typeTag,
    required this.track,
    required this.prompt,
    required this.options,
    required this.answerKey,
    required this.whyCorrectKo,
    required this.whyWrongKo,
    required this.evidenceSentenceIds,
    required this.sourceLines,
  });

  final int orderIndex;
  final String questionId;
  final String skill;
  final String typeTag;
  final String track;
  final String prompt;
  final OptionMap options;
  final String answerKey;
  final String whyCorrectKo;
  final OptionMap whyWrongKo;
  final List<String> evidenceSentenceIds;
  final List<SourceLine> sourceLines;
}

class TodayQuizRepository {
  const TodayQuizRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<List<QuizQuestionDetail>> loadSessionQuestions(int sessionId) async {
    final items =
        await (_database.select(_database.dailySessionItems)
              ..where((tbl) => tbl.sessionId.equals(sessionId))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.orderIndex)]))
            .get();

    final details = <QuizQuestionDetail>[];
    for (final item in items) {
      details.add(
        await loadQuestionDetail(
          questionId: item.questionId,
          orderIndex: item.orderIndex,
        ),
      );
    }

    return details;
  }

  Future<QuizQuestionDetail> loadQuestionDetail({
    required String questionId,
    required int orderIndex,
  }) async {
    final question = await (_database.select(
      _database.questions,
    )..where((tbl) => tbl.id.equals(questionId))).getSingle();
    final explanation = await (_database.select(
      _database.explanations,
    )..where((tbl) => tbl.questionId.equals(question.id))).getSingle();

    final sourceLines = await _loadSourceLines(question);

    return QuizQuestionDetail(
      orderIndex: orderIndex,
      questionId: question.id,
      skill: question.skill,
      typeTag: question.typeTag,
      track: question.track,
      prompt: question.prompt,
      options: question.optionsJson,
      answerKey: question.answerKey,
      whyCorrectKo: explanation.whyCorrectKo,
      whyWrongKo: explanation.whyWrongKoJson,
      evidenceSentenceIds: explanation.evidenceSentenceIdsJson,
      sourceLines: sourceLines,
    );
  }

  Future<Map<String, AttemptPayload>> loadSessionAttempts(int sessionId) async {
    final rows = await (_database.select(
      _database.attempts,
    )..where((tbl) => tbl.sessionId.equals(sessionId))).get();

    final mapped = <String, AttemptPayload>{};
    for (final row in rows) {
      mapped[row.questionId] = AttemptPayload.decode(row.userAnswerJson);
    }
    return mapped;
  }

  Future<SessionProgress> loadSessionProgress(int sessionId) async {
    final summaryRows = await _database
        .customSelect(
          'SELECT '
          'COUNT(*) AS completed, '
          'SUM(CASE WHEN q.skill = \'LISTENING\' THEN 1 ELSE 0 END) AS listening_completed, '
          'SUM(CASE WHEN q.skill = \'READING\' THEN 1 ELSE 0 END) AS reading_completed '
          'FROM attempts a '
          'INNER JOIN questions q ON q.id = a.question_id '
          'WHERE a.session_id = ?',
          variables: [Variable<int>(sessionId)],
          readsFrom: {_database.attempts, _database.questions},
        )
        .getSingle();

    return SessionProgress(
      completed: summaryRows.read<int?>('completed') ?? 0,
      listeningCompleted: summaryRows.read<int?>('listening_completed') ?? 0,
      readingCompleted: summaryRows.read<int?>('reading_completed') ?? 0,
    );
  }

  Future<int> findFirstUnansweredOrderIndex({required int sessionId}) async {
    final row = await _database
        .customSelect(
          'SELECT dsi.order_index AS order_index '
          'FROM daily_session_items dsi '
          'LEFT JOIN attempts a '
          '  ON a.session_id = dsi.session_id '
          ' AND a.question_id = dsi.question_id '
          'WHERE dsi.session_id = ? AND a.id IS NULL '
          'ORDER BY dsi.order_index ASC '
          'LIMIT 1',
          variables: [Variable<int>(sessionId)],
          readsFrom: {_database.dailySessionItems, _database.attempts},
        )
        .getSingleOrNull();

    if (row == null) {
      return 6;
    }
    return row.read<int>('order_index');
  }

  Future<SessionCompletionReport> loadSessionCompletionReport(
    int sessionId,
  ) async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'q.skill AS skill, '
          'a.is_correct AS is_correct, '
          'a.user_answer_json AS user_answer_json '
          'FROM daily_session_items dsi '
          'INNER JOIN questions q ON q.id = dsi.question_id '
          'LEFT JOIN attempts a '
          '  ON a.session_id = dsi.session_id '
          ' AND a.question_id = dsi.question_id '
          'WHERE dsi.session_id = ? '
          'ORDER BY dsi.order_index ASC',
          variables: [Variable<int>(sessionId)],
          readsFrom: {
            _database.dailySessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .get();

    var listeningCorrectCount = 0;
    var readingCorrectCount = 0;
    var wrongCount = 0;
    final wrongReasonCounts = <String, int>{};

    for (final row in rows) {
      final isCorrect = row.read<bool?>('is_correct');
      if (isCorrect == null) {
        continue;
      }

      final skill = row.read<String>('skill');
      if (isCorrect) {
        if (skill == 'LISTENING') {
          listeningCorrectCount += 1;
        } else if (skill == 'READING') {
          readingCorrectCount += 1;
        }
        continue;
      }

      wrongCount += 1;
      final payload = AttemptPayload.decode(
        row.read<String>('user_answer_json'),
      );
      final wrongReasonTag = payload.wrongReasonTag;
      if (wrongReasonTag == null) {
        continue;
      }
      wrongReasonCounts.update(
        wrongReasonTag,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    String? topWrongReasonTag;
    if (wrongReasonCounts.isNotEmpty) {
      final sortedEntries = wrongReasonCounts.entries.toList(growable: false)
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) {
            return byCount;
          }
          return a.key.compareTo(b.key);
        });
      topWrongReasonTag = sortedEntries.first.key;
    }

    return SessionCompletionReport(
      listeningCorrectCount: listeningCorrectCount,
      readingCorrectCount: readingCorrectCount,
      wrongCount: wrongCount,
      topWrongReasonTag: topWrongReasonTag,
    );
  }

  Future<void> saveAttempt({
    required int sessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    String? wrongReasonTag,
  }) async {
    return saveAttemptIdempotent(
      sessionId: sessionId,
      questionId: questionId,
      selectedAnswer: selectedAnswer,
      isCorrect: isCorrect,
      wrongReasonTag: wrongReasonTag,
    );
  }

  Future<void> saveAttemptIdempotent({
    required int sessionId,
    required String questionId,
    required String selectedAnswer,
    required bool isCorrect,
    String? wrongReasonTag,
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
      final existingAttemptId = await _findSessionAttemptId(
        sessionId: sessionId,
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
                  sessionId: Value(sessionId),
                  userAnswerJson: payload.encode(),
                  isCorrect: isCorrect,
                  attemptedAt: Value(nowUtc),
                ),
              );
        } catch (error) {
          if (!_isSessionQuestionUniqueConflict(error)) {
            rethrow;
          }

          final conflictedAttemptId = await _findSessionAttemptId(
            sessionId: sessionId,
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

      await _syncCompletedItems(sessionId: sessionId);
    });
  }

  Future<void> deleteTodaySession({
    required String track,
    DateTime? nowLocal,
  }) async {
    final resolvedNow = nowLocal ?? DateTime.now();
    final dayKey = formatDayKey(resolvedNow);
    validateDayKey(dayKey);
    final dayKeyValue = int.parse(dayKey);

    final targetSession =
        await (_database.select(_database.dailySessions)..where(
              (tbl) => tbl.dayKey.equals(dayKeyValue) & tbl.track.equals(track),
            ))
            .getSingleOrNull();
    if (targetSession == null) {
      return;
    }

    await _database.transaction(() async {
      await (_database.delete(
        _database.attempts,
      )..where((tbl) => tbl.sessionId.equals(targetSession.id))).go();

      await (_database.delete(
        _database.dailySessions,
      )..where((tbl) => tbl.id.equals(targetSession.id))).go();
    });
  }

  Future<int?> _findSessionAttemptId({
    required int sessionId,
    required String questionId,
  }) async {
    final row = await _database
        .customSelect(
          'SELECT id FROM attempts '
          'WHERE session_id = ? AND question_id = ? '
          'ORDER BY attempted_at DESC, id DESC '
          'LIMIT 1',
          variables: [Variable<int>(sessionId), Variable<String>(questionId)],
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

  Future<void> _syncCompletedItems({required int sessionId}) async {
    await _database.customUpdate(
      'UPDATE daily_sessions '
      'SET completed_items = MIN('
      '  planned_items, '
      '  (SELECT COUNT(*) FROM attempts WHERE session_id = daily_sessions.id)'
      ') '
      'WHERE id = ?',
      variables: [Variable<int>(sessionId)],
      updates: {_database.dailySessions, _database.attempts},
    );
  }

  bool _isSessionQuestionUniqueConflict(Object error) {
    final message = error.toString();
    return message.contains('2067') ||
        message.contains('ux_attempts_session_question') ||
        message.contains(
          'UNIQUE constraint failed: attempts.session_id, attempts.question_id',
        ) ||
        message.contains('attempts.session_id, attempts.question_id');
  }

  Future<List<SourceLine>> _loadSourceLines(Question question) async {
    if (question.skill == 'LISTENING') {
      final script = await (_database.select(
        _database.scripts,
      )..where((tbl) => tbl.id.equals(question.scriptId!))).getSingle();

      final sentenceById = <String, Sentence>{
        for (final sentence in script.sentencesJson) sentence.id: sentence,
      };

      final lines = <SourceLine>[];
      for (var i = 0; i < script.turnsJson.length; i++) {
        final Turn turn = script.turnsJson[i];
        final texts = <String>[];
        for (final sentenceId in turn.sentenceIds) {
          final sentence = sentenceById[sentenceId];
          if (sentence != null) {
            texts.add(sentence.text);
          }
        }

        lines.add(
          SourceLine(
            sentenceIds: turn.sentenceIds,
            text: texts.join(' '),
            index: i,
            speaker: turn.speaker,
          ),
        );
      }

      return lines;
    }

    final passage = await (_database.select(
      _database.passages,
    )..where((tbl) => tbl.id.equals(question.passageId!))).getSingle();

    final lines = <SourceLine>[];
    for (var i = 0; i < passage.sentencesJson.length; i++) {
      final sentence = passage.sentencesJson[i];
      lines.add(
        SourceLine(sentenceIds: [sentence.id], text: sentence.text, index: i),
      );
    }

    return lines;
  }

  void _validateSelectedAnswer(String answer) {
    if (!optionKeys.contains(answer)) {
      throw FormatException('selectedAnswer must be one of A..E.');
    }
  }
}
