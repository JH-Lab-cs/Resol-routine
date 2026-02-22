import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/time/day_key.dart';
import '../../today/data/attempt_payload.dart';
import 'models/report_schema_v1.dart';

typedef AppVersionLoader = Future<String?> Function();

class ReportExportPayload {
  const ReportExportPayload({
    required this.fileName,
    required this.jsonPayload,
    required this.report,
  });

  final String fileName;
  final String jsonPayload;
  final ReportSchema report;
}

class ReportExportRepository {
  ReportExportRepository({
    required AppDatabase database,
    AppVersionLoader? appVersionLoader,
  }) : _database = database,
       _appVersionLoader = appVersionLoader ?? _defaultAppVersionLoader;

  static const Set<String> _supportedTracks = <String>{'M3', 'H1', 'H2', 'H3'};
  static const int _maxPayloadLength = DbTextLimits.reportPayloadMax;

  final AppDatabase _database;
  final AppVersionLoader _appVersionLoader;

  Future<ReportSchema> buildCumulativeReport({
    required String track,
    DateTime? nowLocal,
  }) async {
    _validateTrack(track);

    final resolvedNow = nowLocal ?? DateTime.now();
    final student = await _loadStudent();
    final days = await _loadDays(track: track);

    return ReportSchema.v2(
      generatedAt: resolvedNow.toUtc(),
      appVersion: await _appVersionLoader(),
      student: student,
      days: days,
    );
  }

  Future<ReportDay?> buildTodayReport({
    required String track,
    DateTime? nowLocal,
  }) async {
    final resolvedNow = nowLocal ?? DateTime.now();
    final todayKey = formatDayKey(resolvedNow);
    final report = await buildCumulativeReport(
      track: track,
      nowLocal: nowLocal,
    );

    for (final day in report.days) {
      if (day.dayKey == todayKey) {
        return day;
      }
    }
    return null;
  }

  Future<ReportExportPayload> buildExportPayload({
    required String track,
    DateTime? nowLocal,
  }) async {
    final resolvedNow = nowLocal ?? DateTime.now();
    final dayKey = formatDayKey(resolvedNow);
    final cumulativeReport = await buildCumulativeReport(
      track: track,
      nowLocal: nowLocal,
    );
    final prepared = _prepareExportReport(cumulativeReport);

    return ReportExportPayload(
      fileName: buildFileName(dayKey: dayKey, track: track),
      jsonPayload: prepared.canonicalPayload,
      report: prepared.report,
    );
  }

  _PreparedExport _prepareExportReport(ReportSchema cumulativeReport) {
    final fullPayload = cumulativeReport.encodeCompact();
    if (fullPayload.length <= _maxPayloadLength) {
      return _PreparedExport(
        report: cumulativeReport,
        canonicalPayload: fullPayload,
      );
    }

    final totalDays = cumulativeReport.days.length;
    if (totalDays == 0) {
      throw FormatException(
        'Export report payload exceeds $_maxPayloadLength characters.',
      );
    }

    final trimResult = _findMaxFittingRecentDays(cumulativeReport);
    if (trimResult.keptDays <= 0) {
      throw FormatException(
        'Export report payload exceeds $_maxPayloadLength characters even with one day.',
      );
    }

    final trimmedReport = _copyWithRecentDays(
      cumulativeReport,
      trimResult.keptDays,
    );
    return _PreparedExport(
      report: trimmedReport,
      canonicalPayload: trimResult.payload,
    );
  }

  _TrimResult _findMaxFittingRecentDays(ReportSchema report) {
    var left = 1;
    var right = report.days.length;
    var best = _TrimResult(keptDays: 0, payload: '');

    while (left <= right) {
      final mid = (left + right) >> 1;
      final candidate = _copyWithRecentDays(report, mid);
      final payload = candidate.encodeCompact();

      if (payload.length <= _maxPayloadLength) {
        best = _TrimResult(keptDays: mid, payload: payload);
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return best;
  }

  ReportSchema _copyWithRecentDays(ReportSchema original, int keepDays) {
    final boundedKeepDays = keepDays.clamp(0, original.days.length);
    final trimmedDays = original.days
        .take(boundedKeepDays)
        .toList(growable: false);

    if (original.schemaVersion == reportSchemaV1) {
      return ReportSchema.v1(
        generatedAt: original.generatedAt,
        appVersion: original.appVersion,
        student: original.student,
        days: trimmedDays,
      );
    }

    return ReportSchema.v2(
      generatedAt: original.generatedAt,
      appVersion: original.appVersion,
      student: original.student,
      days: trimmedDays,
    );
  }

  String buildFileName({required String dayKey, required String track}) {
    validateDayKey(dayKey);
    _validateTrack(track);
    return 'resolroutine_report_${dayKey}_$track.json';
  }

  Future<ReportStudent> _loadStudent() async {
    final row = await (_database.select(
      _database.userSettings,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();

    if (row == null) {
      return const ReportStudent();
    }

    final normalizedDisplayName = row.displayName.trim();
    return ReportStudent(
      role: _supportedRoleOrNull(row.role),
      displayName: normalizedDisplayName.isEmpty ? null : normalizedDisplayName,
      track: _trackOrNull(row.track),
    );
  }

  Future<List<ReportDay>> _loadDays({required String track}) async {
    final rows = await _database
        .customSelect(
          'SELECT '
          'ds.id AS session_id, '
          'ds.day_key AS day_key, '
          'ds.track AS track, '
          'dsi.order_index AS order_index, '
          'dsi.question_id AS question_id, '
          'q.skill AS skill, '
          'q.type_tag AS type_tag, '
          'a.is_correct AS is_correct, '
          'a.user_answer_json AS user_answer_json '
          'FROM daily_sessions ds '
          'INNER JOIN daily_session_items dsi ON dsi.session_id = ds.id '
          'INNER JOIN questions q ON q.id = dsi.question_id '
          'LEFT JOIN attempts a '
          '  ON a.session_id = ds.id '
          ' AND a.question_id = dsi.question_id '
          'WHERE ds.track = ? '
          'ORDER BY ds.day_key DESC, ds.id DESC, dsi.order_index ASC',
          variables: <Variable<Object>>[Variable<String>(track)],
          readsFrom: {
            _database.dailySessions,
            _database.dailySessionItems,
            _database.questions,
            _database.attempts,
          },
        )
        .get();

    final dayBuilders = <String, _DayBuilder>{};
    for (final row in rows) {
      final dayKey = _formatDayKey(row.read<int>('day_key'));
      final rowTrack = _trackOrNull(row.read<String>('track'));
      if (rowTrack == null) {
        throw FormatException(
          'Unsupported track on daily_sessions row: ${row.read<String>('track')}',
        );
      }
      final dayBuilder = dayBuilders.putIfAbsent(
        _dayBuilderKey(dayKey: dayKey, track: rowTrack),
        () => _DayBuilder(dayKey: dayKey, track: rowTrack),
      );

      final isCorrect = _sqliteBoolOrNull(row.read<int?>('is_correct'));
      if (isCorrect == null) {
        continue;
      }

      final skill = skillFromDb(row.read<String>('skill'));
      final question = ReportQuestionResult(
        questionId: row.read<String>('question_id'),
        skill: skill,
        typeTag: row.read<String>('type_tag'),
        isCorrect: isCorrect,
        wrongReasonTag: isCorrect
            ? null
            : _decodeWrongReasonTagOrNull(
                row.read<String?>('user_answer_json'),
              ),
      );
      dayBuilder.addSolvedQuestion(question);
    }

    final vocabQuizByDayKey = await _loadVocabQuizByDayKey(track: track);
    final parsedTrack = trackFromDb(track);
    for (final dayKey in vocabQuizByDayKey.keys) {
      dayBuilders.putIfAbsent(
        _dayBuilderKey(dayKey: dayKey, track: parsedTrack),
        () => _DayBuilder(dayKey: dayKey, track: parsedTrack),
      );
    }

    final builtDays = dayBuilders.values
        .map(
          (builder) =>
              builder.build(vocabQuiz: vocabQuizByDayKey[builder.dayKey]),
        )
        .toList(growable: false);
    builtDays.sort((left, right) => right.dayKey.compareTo(left.dayKey));

    for (var i = 0; i < builtDays.length; i++) {
      // Re-validate serialized output so exported files always satisfy schema guards.
      ReportDay.fromJson(
        builtDays[i].toJson(),
        path: 'days[$i]',
        schemaVersion: reportSchemaV2,
      );
    }

    return builtDays;
  }

  String _dayBuilderKey({required String dayKey, required Track track}) {
    return '$dayKey|${track.dbValue}';
  }

  Future<Map<String, ReportVocabQuizSummary>> _loadVocabQuizByDayKey({
    required String track,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT day_key, total_count, correct_count, wrong_vocab_ids_json '
          'FROM vocab_quiz_results '
          'WHERE track = ?',
          variables: <Variable<Object>>[Variable<String>(track)],
          readsFrom: {_database.vocabQuizResults},
        )
        .get();

    final byDayKey = <String, ReportVocabQuizSummary>{};
    for (final row in rows) {
      final dayKey = _formatDayKey(row.read<int>('day_key'));
      final wrongVocabIds = _decodeWrongVocabIds(
        row.read<String>('wrong_vocab_ids_json'),
        path: 'vocabQuizResults[$dayKey].wrongVocabIdsJson',
      );
      byDayKey[dayKey] = ReportVocabQuizSummary.fromJson(<String, Object?>{
        'totalCount': row.read<int>('total_count'),
        'correctCount': row.read<int>('correct_count'),
        'wrongVocabIds': wrongVocabIds,
      }, path: 'vocabQuizResults[$dayKey]');
    }
    return byDayKey;
  }

  String _formatDayKey(int dayKey) {
    final text = dayKey.toString().padLeft(8, '0');
    validateDayKey(text);
    return text;
  }

  WrongReasonTag? _decodeWrongReasonTagOrNull(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      return null;
    }

    try {
      return AttemptPayload.decode(payloadJson).wrongReasonTag;
    } on FormatException {
      return null;
    }
  }

  List<Object?> _decodeWrongVocabIds(
    String payloadJson, {
    required String path,
  }) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! List<Object?>) {
      throw FormatException('Expected "$path" to be a JSON array.');
    }
    return decoded;
  }

  String? _supportedRoleOrNull(String rawRole) {
    if (rawRole == 'STUDENT' || rawRole == 'PARENT') {
      return rawRole;
    }
    return null;
  }

  Track? _trackOrNull(String rawTrack) {
    try {
      return trackFromDb(rawTrack);
    } on FormatException {
      return null;
    }
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

  void _validateTrack(String track) {
    if (_supportedTracks.contains(track)) {
      return;
    }
    throw FormatException('Unsupported track: "$track"');
  }
}

class _PreparedExport {
  const _PreparedExport({required this.report, required this.canonicalPayload});

  final ReportSchema report;
  final String canonicalPayload;
}

class _TrimResult {
  const _TrimResult({required this.keptDays, required this.payload});

  final int keptDays;
  final String payload;
}

class _DayBuilder {
  _DayBuilder({required this.dayKey, required this.track});

  final String dayKey;
  final Track track;

  final List<ReportQuestionResult> _questions = <ReportQuestionResult>[];
  final Map<WrongReasonTag, int> _wrongReasonCounts = <WrongReasonTag, int>{};

  int _listeningCorrect = 0;
  int _readingCorrect = 0;

  void addSolvedQuestion(ReportQuestionResult question) {
    if (_questions.length >= reportMaxQuestionsPerDay) {
      throw StateError(
        'A daily report must not exceed $reportMaxQuestionsPerDay solved questions.',
      );
    }

    _questions.add(question);

    if (question.isCorrect) {
      if (question.skill == Skill.listening) {
        _listeningCorrect += 1;
      } else {
        _readingCorrect += 1;
      }
      return;
    }

    final wrongReasonTag = question.wrongReasonTag;
    if (wrongReasonTag == null) {
      return;
    }

    _wrongReasonCounts.update(
      wrongReasonTag,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  ReportDay build({ReportVocabQuizSummary? vocabQuiz}) {
    final solvedCount = _questions.length;
    final wrongCount = solvedCount - _listeningCorrect - _readingCorrect;

    return ReportDay(
      dayKey: dayKey,
      track: track,
      solvedCount: solvedCount,
      wrongCount: wrongCount,
      listeningCorrect: _listeningCorrect,
      readingCorrect: _readingCorrect,
      wrongReasonCounts: Map<WrongReasonTag, int>.unmodifiable(
        _wrongReasonCounts,
      ),
      questions: List<ReportQuestionResult>.unmodifiable(_questions),
      vocabQuiz: vocabQuiz,
    );
  }
}

Future<String?> _defaultAppVersionLoader() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform().timeout(
      const Duration(milliseconds: 800),
    );
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  } catch (_) {
    return null;
  }
}
