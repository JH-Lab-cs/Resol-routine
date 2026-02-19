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

  Future<void> saveAttempt({
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

    await _database.transaction(() async {
      final alreadySaved = await _database
          .customSelect(
            'SELECT id FROM attempts WHERE session_id = ? AND question_id = ? LIMIT 1',
            variables: [Variable<int>(sessionId), Variable<String>(questionId)],
            readsFrom: {_database.attempts},
          )
          .getSingleOrNull();
      if (alreadySaved != null) {
        return;
      }

      final payload = AttemptPayload(
        selectedAnswer: selectedAnswer,
        wrongReasonTag: wrongReasonTag,
      );

      await _database
          .into(_database.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: questionId,
              sessionId: Value(sessionId),
              userAnswerJson: payload.encode(),
              isCorrect: isCorrect,
            ),
          );

      await _database.customUpdate(
        'UPDATE daily_sessions '
        'SET completed_items = MIN(planned_items, completed_items + 1) '
        'WHERE id = ?',
        variables: [Variable<int>(sessionId)],
        updates: {_database.dailySessions},
      );
    });
  }

  Future<void> deleteTodaySession({
    required String track,
    DateTime? nowLocal,
  }) async {
    final resolvedNow = nowLocal ?? DateTime.now();
    final dayKey = formatDayKey(resolvedNow);
    validateDayKey(dayKey);

    await (_database.delete(_database.dailySessions)..where(
          (tbl) =>
              tbl.dayKey.equals(int.parse(dayKey)) & tbl.track.equals(track),
        ))
        .go();
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
