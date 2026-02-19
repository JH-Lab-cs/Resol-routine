import '../../../core/database/app_database.dart';
import '../../../core/time/day_key.dart';
import '../../today/data/attempt_payload.dart';
import '../../today/data/today_quiz_repository.dart';

class WrongNoteListItem {
  const WrongNoteListItem({
    required this.attemptId,
    required this.dayKey,
    required this.skill,
    required this.typeTag,
    required this.track,
    required this.attemptedAt,
    required this.questionId,
  });

  final int attemptId;
  final String dayKey;
  final String skill;
  final String typeTag;
  final String track;
  final DateTime attemptedAt;
  final String questionId;
}

class WrongNoteDetail {
  const WrongNoteDetail({
    required this.attemptId,
    required this.dayKey,
    required this.userAnswer,
    required this.wrongReasonTag,
    required this.question,
  });

  final int attemptId;
  final String dayKey;
  final String userAnswer;
  final String? wrongReasonTag;
  final QuizQuestionDetail question;
}

class WrongNoteRepository {
  WrongNoteRepository({required AppDatabase database})
    : _database = database,
      _quizRepository = TodayQuizRepository(database: database);

  final AppDatabase _database;
  final TodayQuizRepository _quizRepository;

  Future<List<WrongNoteListItem>> listIncorrectAttempts() async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'a.id AS attempt_id, '
          'a.question_id AS question_id, '
          'a.attempted_at AS attempted_at, '
          'COALESCE(ds.day_key, 0) AS day_key, '
          'q.skill AS skill, '
          'q.type_tag AS type_tag, '
          'q.track AS track '
          'FROM attempts a '
          'INNER JOIN questions q ON q.id = a.question_id '
          'LEFT JOIN daily_sessions ds ON ds.id = a.session_id '
          'WHERE a.is_correct = 0 '
          'ORDER BY a.attempted_at DESC',
          readsFrom: {
            _database.attempts,
            _database.questions,
            _database.dailySessions,
          },
        )
        .get();

    return rows
        .map(
          (row) => WrongNoteListItem(
            attemptId: row.read<int>('attempt_id'),
            questionId: row.read<String>('question_id'),
            dayKey: _formatDayKeyValue(row.read<int>('day_key')),
            skill: row.read<String>('skill'),
            typeTag: row.read<String>('type_tag'),
            track: row.read<String>('track'),
            attemptedAt: row.read<DateTime>('attempted_at'),
          ),
        )
        .toList(growable: false);
  }

  Future<WrongNoteDetail> loadDetail(int attemptId) async {
    final attempt = await (_database.select(
      _database.attempts,
    )..where((tbl) => tbl.id.equals(attemptId))).getSingle();

    final session = attempt.sessionId == null
        ? null
        : await (_database.select(_database.dailySessions)
                ..where((tbl) => tbl.id.equals(attempt.sessionId!)))
              .getSingleOrNull();

    final payload = AttemptPayload.decode(attempt.userAnswerJson);
    final question = await _quizRepository.loadQuestionDetail(
      questionId: attempt.questionId,
      orderIndex: 0,
    );

    return WrongNoteDetail(
      attemptId: attemptId,
      dayKey: _formatDayKeyValue(session?.dayKey ?? 0),
      userAnswer: payload.selectedAnswer,
      wrongReasonTag: payload.wrongReasonTag,
      question: question,
    );
  }

  String _formatDayKeyValue(int dayKey) {
    if (dayKey <= 0) {
      return '-';
    }

    final asText = dayKey.toString().padLeft(8, '0');
    try {
      validateDayKey(asText);
    } on FormatException {
      return asText;
    }

    return '${asText.substring(0, 4)}-${asText.substring(4, 6)}-${asText.substring(6, 8)}';
  }
}
