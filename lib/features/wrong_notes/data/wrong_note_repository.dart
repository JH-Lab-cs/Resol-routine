import 'package:drift/drift.dart' show QueryRow;

import '../../../core/database/app_database.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/time/day_key.dart';
import '../../today/data/attempt_payload.dart';
import '../../today/data/today_quiz_repository.dart';

enum WrongNoteSourceKind { daily, mock }

class WrongNoteListItem {
  const WrongNoteListItem({
    required this.attemptId,
    required this.dayKey,
    required this.skill,
    required this.typeTag,
    required this.track,
    required this.attemptedAt,
    required this.questionId,
    required this.sourceKind,
    required this.mockSessionId,
    required this.mockType,
    required this.periodKey,
    required this.completedAt,
  });

  final int attemptId;
  final String dayKey;
  final Skill skill;
  final String typeTag;
  final Track track;
  final DateTime attemptedAt;
  final String questionId;
  final WrongNoteSourceKind sourceKind;
  final int? mockSessionId;
  final MockExamType? mockType;
  final String? periodKey;
  final DateTime? completedAt;
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
  final WrongReasonTag? wrongReasonTag;
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
          'a.session_id AS session_id, '
          'a.mock_session_id AS mock_session_id, '
          'a.question_id AS question_id, '
          'a.attempted_at AS attempted_at, '
          'COALESCE(ds.day_key, 0) AS day_key, '
          'q.skill AS skill, '
          'q.type_tag AS type_tag, '
          'q.track AS track, '
          'mes.exam_type AS mock_exam_type, '
          'mes.period_key AS mock_period_key, '
          'mes.completed_at AS mock_completed_at '
          'FROM attempts a '
          'INNER JOIN questions q ON q.id = a.question_id '
          'LEFT JOIN daily_sessions ds ON ds.id = a.session_id '
          'LEFT JOIN mock_exam_sessions mes ON mes.id = a.mock_session_id '
          'WHERE a.is_correct = 0 '
          'ORDER BY a.id DESC',
          readsFrom: {
            _database.attempts,
            _database.questions,
            _database.dailySessions,
            _database.mockExamSessions,
          },
        )
        .get();

    final entries = rows.map(_toSortEntry).toList(growable: false);
    entries.sort(_compareEntries);
    return entries.map((entry) => entry.item).toList(growable: false);
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
    final mockSession = attempt.mockSessionId == null
        ? null
        : await (_database.select(_database.mockExamSessions)
                ..where((tbl) => tbl.id.equals(attempt.mockSessionId!)))
              .getSingleOrNull();

    final payload = AttemptPayload.decode(attempt.userAnswerJson);
    final question = await _quizRepository.loadQuestionDetail(
      questionId: attempt.questionId,
      orderIndex: 0,
    );
    final formattedMockDate = _formatDateOnly(
      mockSession?.completedAt ?? attempt.attemptedAt,
    );

    return WrongNoteDetail(
      attemptId: attemptId,
      dayKey: session == null
          ? formattedMockDate
          : _formatDayKeyValue(session.dayKey),
      userAnswer: payload.selectedAnswer,
      wrongReasonTag: payload.wrongReasonTag,
      question: question,
    );
  }

  _WrongNoteSortEntry _toSortEntry(QueryRow row) {
    final attemptId = row.read<int>('attempt_id');
    final questionId = row.read<String>('question_id');
    final attemptedAt = row.read<DateTime>('attempted_at');
    final dayKeyValue = row.read<int>('day_key');
    final skill = skillFromDb(row.read<String>('skill'));
    final typeTag = row.read<String>('type_tag');
    final track = trackFromDb(row.read<String>('track'));
    final mockSessionId = row.read<int?>('mock_session_id');
    final sourceKind = mockSessionId == null
        ? WrongNoteSourceKind.daily
        : WrongNoteSourceKind.mock;
    final mockTypeRaw = row.read<String?>('mock_exam_type');
    final mockType = mockTypeRaw == null
        ? null
        : mockExamTypeFromDb(mockTypeRaw);
    final periodKey = row.read<String?>('mock_period_key');
    final completedAt = row.read<DateTime?>('mock_completed_at');
    final activityAt = sourceKind == WrongNoteSourceKind.mock
        ? (completedAt ?? attemptedAt)
        : _dailyActivityAt(dayKeyValue, attemptedAt);

    final item = WrongNoteListItem(
      attemptId: attemptId,
      questionId: questionId,
      dayKey: _formatDayKeyValue(dayKeyValue),
      skill: skill,
      typeTag: typeTag,
      track: track,
      attemptedAt: attemptedAt,
      sourceKind: sourceKind,
      mockSessionId: mockSessionId,
      mockType: mockType,
      periodKey: periodKey,
      completedAt: completedAt,
    );
    return _WrongNoteSortEntry(
      item: item,
      activityAt: activityAt,
      dayKeyValue: dayKeyValue,
      mockCompletedAt: completedAt,
    );
  }

  int _compareEntries(_WrongNoteSortEntry left, _WrongNoteSortEntry right) {
    final byActivity = right.activityAt.compareTo(left.activityAt);
    if (byActivity != 0) {
      return byActivity;
    }

    final leftKind = left.item.sourceKind;
    final rightKind = right.item.sourceKind;
    if (leftKind == rightKind) {
      if (leftKind == WrongNoteSourceKind.daily) {
        final byDay = right.dayKeyValue.compareTo(left.dayKeyValue);
        if (byDay != 0) {
          return byDay;
        }
      } else {
        final leftCompleted = left.mockCompletedAt ?? left.item.attemptedAt;
        final rightCompleted = right.mockCompletedAt ?? right.item.attemptedAt;
        final byCompleted = rightCompleted.compareTo(leftCompleted);
        if (byCompleted != 0) {
          return byCompleted;
        }
      }
    }

    final byAttemptId = right.item.attemptId.compareTo(left.item.attemptId);
    if (byAttemptId != 0) {
      return byAttemptId;
    }
    return left.item.questionId.compareTo(right.item.questionId);
  }

  DateTime _dailyActivityAt(int dayKey, DateTime fallback) {
    if (dayKey <= 0) {
      return fallback;
    }

    final asText = dayKey.toString().padLeft(8, '0');
    try {
      validateDayKey(asText);
    } on FormatException {
      return fallback;
    }
    final year = int.tryParse(asText.substring(0, 4));
    final month = int.tryParse(asText.substring(4, 6));
    final day = int.tryParse(asText.substring(6, 8));
    if (year == null || month == null || day == null) {
      return fallback;
    }
    final candidate = DateTime.utc(year, month, day, 23, 59, 59, 999);
    return candidate;
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

  String _formatDateOnly(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _WrongNoteSortEntry {
  const _WrongNoteSortEntry({
    required this.item,
    required this.activityAt,
    required this.dayKeyValue,
    required this.mockCompletedAt,
  });

  final WrongNoteListItem item;
  final DateTime activityAt;
  final int dayKeyValue;
  final DateTime? mockCompletedAt;
}
