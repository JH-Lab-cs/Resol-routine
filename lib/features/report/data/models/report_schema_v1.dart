import 'dart:convert';

import '../../../../core/database/db_text_limits.dart';
import '../../../../core/domain/domain_enums.dart';
import '../../../../core/security/hidden_unicode.dart';
import '../../../../core/time/day_key.dart';

typedef ReportJsonMap = Map<String, Object?>;

const int reportSchemaV1 = 1;
const int reportSchemaV2 = 2;
const int reportSchemaV3 = 3;
const int reportCurrentSchemaVersion = reportSchemaV3;
const int reportMaxDays = 3660;
const int reportMaxQuestionsPerDay = 6;
const int reportMaxCorrectPerSkill = 3;
const int reportMaxVocabQuizTotalCount = 20;
const int reportMaxBookmarkedVocabIds = 2000;
const int reportMaxAppVersionLength = 64;

const Set<String> _supportedRoles = <String>{'STUDENT', 'PARENT'};

class ReportSchema {
  const ReportSchema({
    required this.schemaVersion,
    required this.generatedAt,
    required this.appVersion,
    required this.student,
    required this.days,
    required this.vocabBookmarks,
  });

  final int schemaVersion;
  final DateTime generatedAt;
  final String? appVersion;
  final ReportStudent student;
  final List<ReportDay> days;
  final ReportVocabBookmarks? vocabBookmarks;

  factory ReportSchema.v1({
    required DateTime generatedAt,
    String? appVersion,
    required ReportStudent student,
    required List<ReportDay> days,
  }) {
    return ReportSchema(
      schemaVersion: reportSchemaV1,
      generatedAt: generatedAt.toUtc(),
      appVersion: appVersion,
      student: student,
      days: List<ReportDay>.unmodifiable(days),
      vocabBookmarks: null,
    );
  }

  factory ReportSchema.v2({
    required DateTime generatedAt,
    String? appVersion,
    required ReportStudent student,
    required List<ReportDay> days,
  }) {
    return ReportSchema(
      schemaVersion: reportSchemaV2,
      generatedAt: generatedAt.toUtc(),
      appVersion: appVersion,
      student: student,
      days: List<ReportDay>.unmodifiable(days),
      vocabBookmarks: null,
    );
  }

  factory ReportSchema.v3({
    required DateTime generatedAt,
    String? appVersion,
    required ReportStudent student,
    required List<ReportDay> days,
    required ReportVocabBookmarks vocabBookmarks,
  }) {
    return ReportSchema(
      schemaVersion: reportSchemaV3,
      generatedAt: generatedAt.toUtc(),
      appVersion: appVersion,
      student: student,
      days: List<ReportDay>.unmodifiable(days),
      vocabBookmarks: vocabBookmarks,
    );
  }

  factory ReportSchema.fromJson(ReportJsonMap json, {String path = 'root'}) {
    final schemaVersion = _readRequiredInt(
      json,
      'schemaVersion',
      path: '$path.schemaVersion',
    );
    final allowedRootKeys = switch (schemaVersion) {
      reportSchemaV1 || reportSchemaV2 => const <String>{
        'schemaVersion',
        'generatedAt',
        'appVersion',
        'student',
        'days',
      },
      reportSchemaV3 => const <String>{
        'schemaVersion',
        'generatedAt',
        'appVersion',
        'student',
        'days',
        'vocabBookmarks',
      },
      _ => throw FormatException(
        'Expected "$path.schemaVersion" to be '
        '$reportSchemaV1, $reportSchemaV2, or $reportSchemaV3.',
      ),
    };
    _validateAllowedKeys(json, allowedRootKeys, path: path);

    final generatedAtRaw = _readRequiredString(
      json,
      'generatedAt',
      path: '$path.generatedAt',
      maxLength: 64,
    );
    final generatedAt = DateTime.tryParse(generatedAtRaw);
    if (generatedAt == null) {
      throw FormatException(
        'Expected "$path.generatedAt" to be a valid ISO-8601 datetime.',
      );
    }

    final appVersion = _readOptionalString(
      json,
      'appVersion',
      path: '$path.appVersion',
      maxLength: reportMaxAppVersionLength,
    );

    final student = ReportStudent.fromJson(
      _readRequiredObject(json, 'student', path: '$path.student'),
      path: '$path.student',
    );

    final daysJson = _readRequiredArray(json, 'days', path: '$path.days');
    if (daysJson.length > reportMaxDays) {
      throw FormatException('Expected "$path.days" length <= $reportMaxDays.');
    }

    final days = <ReportDay>[];
    final dayKeys = <String>{};
    for (var i = 0; i < daysJson.length; i++) {
      final day = ReportDay.fromJson(
        _asObject(daysJson[i], path: '$path.days[$i]'),
        path: '$path.days[$i]',
        schemaVersion: schemaVersion,
      );
      final duplicateKey = '${day.dayKey}|${day.track.dbValue}';
      if (!dayKeys.add(duplicateKey)) {
        throw FormatException(
          'Duplicated day entry at "$path.days[$i]": $duplicateKey.',
        );
      }
      days.add(day);
    }

    ReportVocabBookmarks? vocabBookmarks;
    if (schemaVersion == reportSchemaV3) {
      vocabBookmarks = ReportVocabBookmarks.fromJson(
        _readRequiredObject(
          json,
          'vocabBookmarks',
          path: '$path.vocabBookmarks',
        ),
        path: '$path.vocabBookmarks',
      );
    }

    return ReportSchema(
      schemaVersion: schemaVersion,
      generatedAt: generatedAt.toUtc(),
      appVersion: appVersion,
      student: student,
      days: List<ReportDay>.unmodifiable(days),
      vocabBookmarks: vocabBookmarks,
    );
  }

  factory ReportSchema.decode(String rawJson, {String path = 'root'}) {
    final decoded = jsonDecode(rawJson);
    return ReportSchema.fromJson(_asObject(decoded, path: path), path: path);
  }

  ReportJsonMap toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
      'student': student.toJson(),
      'days': days.map((day) => day.toJson()).toList(growable: false),
      if (vocabBookmarks != null) 'vocabBookmarks': vocabBookmarks!.toJson(),
    };
  }

  String encodePretty() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  String encodeCompact() {
    return jsonEncode(toJson());
  }
}

class ReportStudent {
  const ReportStudent({this.role, this.displayName, this.track});

  final String? role;
  final String? displayName;
  final Track? track;

  factory ReportStudent.fromJson(
    ReportJsonMap json, {
    String path = 'student',
  }) {
    _validateAllowedKeys(json, const <String>{
      'role',
      'displayName',
      'track',
    }, path: path);

    final role = _readOptionalString(
      json,
      'role',
      path: '$path.role',
      maxLength: 16,
    );
    if (role != null && !_supportedRoles.contains(role)) {
      throw FormatException(
        'Expected "$path.role" to be one of STUDENT, PARENT.',
      );
    }

    final displayName = _readOptionalString(
      json,
      'displayName',
      path: '$path.displayName',
      maxLength: DbTextLimits.displayNameMax,
    );
    if (displayName != null) {
      validateNoHiddenUnicode(displayName, path: '$path.displayName');
    }

    final trackRaw = _readOptionalString(
      json,
      'track',
      path: '$path.track',
      maxLength: 2,
    );
    final track = trackRaw == null ? null : trackFromDb(trackRaw);

    return ReportStudent(role: role, displayName: displayName, track: track);
  }

  ReportJsonMap toJson() {
    return <String, Object?>{
      if (role != null) 'role': role,
      if (displayName != null) 'displayName': displayName,
      if (track != null) 'track': track!.dbValue,
    };
  }
}

class ReportDay {
  const ReportDay({
    required this.dayKey,
    required this.track,
    required this.solvedCount,
    required this.wrongCount,
    required this.listeningCorrect,
    required this.readingCorrect,
    required this.wrongReasonCounts,
    required this.questions,
    this.vocabQuiz,
  });

  final String dayKey;
  final Track track;
  final int solvedCount;
  final int wrongCount;
  final int listeningCorrect;
  final int readingCorrect;
  final Map<WrongReasonTag, int> wrongReasonCounts;
  final List<ReportQuestionResult> questions;
  final ReportVocabQuizSummary? vocabQuiz;

  factory ReportDay.fromJson(
    ReportJsonMap json, {
    String path = 'day',
    int schemaVersion = reportSchemaV1,
  }) {
    final supportsVocabQuiz = schemaVersion >= reportSchemaV2;
    final allowedKeys = supportsVocabQuiz
        ? const <String>{
            'dayKey',
            'track',
            'solvedCount',
            'wrongCount',
            'listeningCorrect',
            'readingCorrect',
            'wrongReasonCounts',
            'questions',
            'vocabQuiz',
          }
        : const <String>{
            'dayKey',
            'track',
            'solvedCount',
            'wrongCount',
            'listeningCorrect',
            'readingCorrect',
            'wrongReasonCounts',
            'questions',
          };
    _validateAllowedKeys(json, allowedKeys, path: path);

    final dayKey = _readRequiredString(
      json,
      'dayKey',
      path: '$path.dayKey',
      maxLength: 8,
    );
    validateDayKey(dayKey);

    final track = trackFromDb(
      _readRequiredString(json, 'track', path: '$path.track', maxLength: 2),
    );

    final solvedCount = _readRequiredInt(
      json,
      'solvedCount',
      path: '$path.solvedCount',
    );
    _validateIntRange(
      solvedCount,
      min: 0,
      max: reportMaxQuestionsPerDay,
      path: '$path.solvedCount',
    );

    final wrongCount = _readRequiredInt(
      json,
      'wrongCount',
      path: '$path.wrongCount',
    );
    _validateIntRange(
      wrongCount,
      min: 0,
      max: reportMaxQuestionsPerDay,
      path: '$path.wrongCount',
    );
    if (wrongCount > solvedCount) {
      throw FormatException(
        'Expected "$path.wrongCount" <= "$path.solvedCount".',
      );
    }

    final listeningCorrect = _readRequiredInt(
      json,
      'listeningCorrect',
      path: '$path.listeningCorrect',
    );
    _validateIntRange(
      listeningCorrect,
      min: 0,
      max: reportMaxCorrectPerSkill,
      path: '$path.listeningCorrect',
    );

    final readingCorrect = _readRequiredInt(
      json,
      'readingCorrect',
      path: '$path.readingCorrect',
    );
    _validateIntRange(
      readingCorrect,
      min: 0,
      max: reportMaxCorrectPerSkill,
      path: '$path.readingCorrect',
    );

    final wrongReasonCounts = _parseWrongReasonCounts(
      _readRequiredObject(
        json,
        'wrongReasonCounts',
        path: '$path.wrongReasonCounts',
      ),
      path: '$path.wrongReasonCounts',
    );

    final questionsJson = _readRequiredArray(
      json,
      'questions',
      path: '$path.questions',
    );
    if (questionsJson.length > reportMaxQuestionsPerDay) {
      throw FormatException(
        'Expected "$path.questions" length <= $reportMaxQuestionsPerDay.',
      );
    }

    final questions = <ReportQuestionResult>[];
    for (var i = 0; i < questionsJson.length; i++) {
      questions.add(
        ReportQuestionResult.fromJson(
          _asObject(questionsJson[i], path: '$path.questions[$i]'),
          path: '$path.questions[$i]',
        ),
      );
    }

    ReportVocabQuizSummary? vocabQuiz;
    if (supportsVocabQuiz && json.containsKey('vocabQuiz')) {
      final raw = json['vocabQuiz'];
      if (raw == null) {
        throw FormatException('Expected "$path.vocabQuiz" to be an object.');
      }
      vocabQuiz = ReportVocabQuizSummary.fromJson(
        _asObject(raw, path: '$path.vocabQuiz'),
        path: '$path.vocabQuiz',
      );
    }

    _validateConsistency(
      path: path,
      solvedCount: solvedCount,
      wrongCount: wrongCount,
      listeningCorrect: listeningCorrect,
      readingCorrect: readingCorrect,
      wrongReasonCounts: wrongReasonCounts,
      questions: questions,
      vocabQuiz: vocabQuiz,
    );

    return ReportDay(
      dayKey: dayKey,
      track: track,
      solvedCount: solvedCount,
      wrongCount: wrongCount,
      listeningCorrect: listeningCorrect,
      readingCorrect: readingCorrect,
      wrongReasonCounts: Map<WrongReasonTag, int>.unmodifiable(
        wrongReasonCounts,
      ),
      questions: List<ReportQuestionResult>.unmodifiable(questions),
      vocabQuiz: vocabQuiz,
    );
  }

  ReportJsonMap toJson() {
    final wrongReasonJson = <String, int>{
      for (final tag in WrongReasonTag.values)
        if ((wrongReasonCounts[tag] ?? 0) > 0)
          tag.dbValue: wrongReasonCounts[tag]!,
    };

    return <String, Object?>{
      'dayKey': dayKey,
      'track': track.dbValue,
      'solvedCount': solvedCount,
      'wrongCount': wrongCount,
      'listeningCorrect': listeningCorrect,
      'readingCorrect': readingCorrect,
      'wrongReasonCounts': wrongReasonJson,
      'questions': questions
          .map((question) => question.toJson())
          .toList(growable: false),
      if (vocabQuiz != null) 'vocabQuiz': vocabQuiz!.toJson(),
    };
  }

  static Map<WrongReasonTag, int> _parseWrongReasonCounts(
    ReportJsonMap json, {
    required String path,
  }) {
    if (json.length > WrongReasonTag.values.length) {
      throw FormatException(
        'Expected "$path" to include at most ${WrongReasonTag.values.length} keys.',
      );
    }

    final output = <WrongReasonTag, int>{};
    for (final entry in json.entries) {
      final tag = wrongReasonTagFromDb(entry.key);
      final count = _readIntValue(entry.value, path: '$path.${entry.key}');
      _validateIntRange(
        count,
        min: 1,
        max: reportMaxQuestionsPerDay,
        path: '$path.${entry.key}',
      );
      output[tag] = count;
    }
    return output;
  }

  static void _validateConsistency({
    required String path,
    required int solvedCount,
    required int wrongCount,
    required int listeningCorrect,
    required int readingCorrect,
    required Map<WrongReasonTag, int> wrongReasonCounts,
    required List<ReportQuestionResult> questions,
    required ReportVocabQuizSummary? vocabQuiz,
  }) {
    if (questions.length != solvedCount) {
      throw FormatException(
        'Expected "$path.questions" length to equal "$path.solvedCount".',
      );
    }

    var actualWrongCount = 0;
    var actualListeningCorrect = 0;
    var actualReadingCorrect = 0;
    final actualWrongReasonCounts = <WrongReasonTag, int>{};

    for (final question in questions) {
      if (question.isCorrect) {
        if (question.skill == Skill.listening) {
          actualListeningCorrect += 1;
        } else {
          actualReadingCorrect += 1;
        }
      } else {
        actualWrongCount += 1;
        final wrongReasonTag = question.wrongReasonTag;
        if (wrongReasonTag != null) {
          actualWrongReasonCounts.update(
            wrongReasonTag,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    if (actualWrongCount != wrongCount) {
      throw FormatException(
        'Expected "$path.wrongCount" to equal wrong question count.',
      );
    }
    if (actualListeningCorrect != listeningCorrect) {
      throw FormatException(
        'Expected "$path.listeningCorrect" to equal listening correct count.',
      );
    }
    if (actualReadingCorrect != readingCorrect) {
      throw FormatException(
        'Expected "$path.readingCorrect" to equal reading correct count.',
      );
    }

    if (!_sameWrongReasonCounts(actualWrongReasonCounts, wrongReasonCounts)) {
      throw FormatException(
        'Expected "$path.wrongReasonCounts" to match question-level tags.',
      );
    }

    if (vocabQuiz != null) {
      final wrongLimit = vocabQuiz.totalCount - vocabQuiz.correctCount;
      if (vocabQuiz.wrongVocabIds.length > wrongLimit) {
        throw FormatException(
          'Expected "$path.vocabQuiz.wrongVocabIds" length <= wrong answers.',
        );
      }
    }
  }

  static bool _sameWrongReasonCounts(
    Map<WrongReasonTag, int> a,
    Map<WrongReasonTag, int> b,
  ) {
    for (final tag in WrongReasonTag.values) {
      final left = a[tag] ?? 0;
      final right = b[tag] ?? 0;
      if (left != right) {
        return false;
      }
    }
    return true;
  }
}

class ReportVocabBookmarks {
  const ReportVocabBookmarks({required this.bookmarkedVocabIds});

  final List<String> bookmarkedVocabIds;

  factory ReportVocabBookmarks.fromJson(
    ReportJsonMap json, {
    String path = 'vocabBookmarks',
  }) {
    _validateAllowedKeys(json, const <String>{
      'bookmarkedVocabIds',
    }, path: path);

    final rawIds = _readRequiredArray(
      json,
      'bookmarkedVocabIds',
      path: '$path.bookmarkedVocabIds',
    );
    if (rawIds.length > reportMaxBookmarkedVocabIds) {
      throw FormatException(
        'Expected "$path.bookmarkedVocabIds" length <= $reportMaxBookmarkedVocabIds.',
      );
    }

    final ids = <String>[];
    final seen = <String>{};
    for (var i = 0; i < rawIds.length; i++) {
      final raw = rawIds[i];
      if (raw is! String) {
        throw FormatException(
          'Expected "$path.bookmarkedVocabIds[$i]" to be a string.',
        );
      }
      final normalized = raw.trim();
      if (normalized.isEmpty) {
        throw FormatException(
          'Expected "$path.bookmarkedVocabIds[$i]" to be non-empty.',
        );
      }
      if (normalized.length > DbTextLimits.idMax) {
        throw FormatException(
          'Expected "$path.bookmarkedVocabIds[$i]" length <= ${DbTextLimits.idMax}.',
        );
      }
      validateNoHiddenUnicode(normalized, path: '$path.bookmarkedVocabIds[$i]');
      if (!seen.add(normalized)) {
        throw FormatException(
          'Duplicated value at "$path.bookmarkedVocabIds[$i]".',
        );
      }
      ids.add(normalized);
    }

    return ReportVocabBookmarks(
      bookmarkedVocabIds: List<String>.unmodifiable(ids),
    );
  }

  ReportJsonMap toJson() {
    return <String, Object?>{'bookmarkedVocabIds': bookmarkedVocabIds};
  }
}

class ReportVocabQuizSummary {
  const ReportVocabQuizSummary({
    required this.totalCount,
    required this.correctCount,
    required this.wrongVocabIds,
  });

  final int totalCount;
  final int correctCount;
  final List<String> wrongVocabIds;

  factory ReportVocabQuizSummary.fromJson(
    ReportJsonMap json, {
    String path = 'vocabQuiz',
  }) {
    _validateAllowedKeys(json, const <String>{
      'totalCount',
      'correctCount',
      'wrongVocabIds',
    }, path: path);

    final totalCount = _readRequiredInt(
      json,
      'totalCount',
      path: '$path.totalCount',
    );
    _validateIntRange(
      totalCount,
      min: 0,
      max: reportMaxVocabQuizTotalCount,
      path: '$path.totalCount',
    );

    final correctCount = _readRequiredInt(
      json,
      'correctCount',
      path: '$path.correctCount',
    );
    _validateIntRange(
      correctCount,
      min: 0,
      max: reportMaxVocabQuizTotalCount,
      path: '$path.correctCount',
    );
    if (correctCount > totalCount) {
      throw FormatException('Expected "$path.correctCount" <= totalCount.');
    }

    final rawWrongVocabIds = _readRequiredArray(
      json,
      'wrongVocabIds',
      path: '$path.wrongVocabIds',
    );
    if (rawWrongVocabIds.length > totalCount) {
      throw FormatException(
        'Expected "$path.wrongVocabIds" length <= "$path.totalCount".',
      );
    }

    final wrongVocabIds = <String>[];
    final seen = <String>{};
    for (var i = 0; i < rawWrongVocabIds.length; i++) {
      final raw = rawWrongVocabIds[i];
      if (raw is! String) {
        throw FormatException(
          'Expected "$path.wrongVocabIds[$i]" to be a string.',
        );
      }
      final normalized = raw.trim();
      if (normalized.isEmpty) {
        throw FormatException(
          'Expected "$path.wrongVocabIds[$i]" to be non-empty.',
        );
      }
      if (normalized.length > DbTextLimits.idMax) {
        throw FormatException(
          'Expected "$path.wrongVocabIds[$i]" length <= ${DbTextLimits.idMax}.',
        );
      }
      validateNoHiddenUnicode(normalized, path: '$path.wrongVocabIds[$i]');
      if (!seen.add(normalized)) {
        throw FormatException('Duplicated value at "$path.wrongVocabIds[$i]".');
      }
      wrongVocabIds.add(normalized);
    }

    if (wrongVocabIds.length > totalCount - correctCount) {
      throw FormatException(
        'Expected "$path.wrongVocabIds" length <= wrong answers.',
      );
    }

    return ReportVocabQuizSummary(
      totalCount: totalCount,
      correctCount: correctCount,
      wrongVocabIds: List<String>.unmodifiable(wrongVocabIds),
    );
  }

  ReportJsonMap toJson() {
    return <String, Object?>{
      'totalCount': totalCount,
      'correctCount': correctCount,
      'wrongVocabIds': wrongVocabIds,
    };
  }
}

class ReportQuestionResult {
  const ReportQuestionResult({
    required this.questionId,
    required this.skill,
    required this.typeTag,
    required this.isCorrect,
    required this.wrongReasonTag,
  });

  final String questionId;
  final Skill skill;
  final String typeTag;
  final bool isCorrect;
  final WrongReasonTag? wrongReasonTag;

  factory ReportQuestionResult.fromJson(
    ReportJsonMap json, {
    String path = 'question',
  }) {
    _validateAllowedKeys(json, const <String>{
      'questionId',
      'skill',
      'typeTag',
      'isCorrect',
      'wrongReasonTag',
    }, path: path);

    final questionId = _readRequiredString(
      json,
      'questionId',
      path: '$path.questionId',
      maxLength: DbTextLimits.idMax,
    );
    validateNoHiddenUnicode(questionId, path: '$path.questionId');

    final skill = skillFromDb(
      _readRequiredString(json, 'skill', path: '$path.skill', maxLength: 16),
    );

    final typeTag = _readRequiredString(
      json,
      'typeTag',
      path: '$path.typeTag',
      maxLength: DbTextLimits.typeTagMax,
    );
    validateNoHiddenUnicode(typeTag, path: '$path.typeTag');
    if (skill == Skill.listening && !typeTag.startsWith('L')) {
      throw FormatException(
        'Expected "$path.typeTag" to start with "L" for LISTENING.',
      );
    }
    if (skill == Skill.reading && !typeTag.startsWith('R')) {
      throw FormatException(
        'Expected "$path.typeTag" to start with "R" for READING.',
      );
    }

    final isCorrect = _readRequiredBool(
      json,
      'isCorrect',
      path: '$path.isCorrect',
    );

    final wrongReasonRaw = _readOptionalString(
      json,
      'wrongReasonTag',
      path: '$path.wrongReasonTag',
      maxLength: 16,
    );
    final wrongReasonTag = wrongReasonRaw == null
        ? null
        : wrongReasonTagFromDb(wrongReasonRaw);

    if (isCorrect && wrongReasonTag != null) {
      throw FormatException(
        'Expected "$path.wrongReasonTag" to be null when isCorrect is true.',
      );
    }

    return ReportQuestionResult(
      questionId: questionId,
      skill: skill,
      typeTag: typeTag,
      isCorrect: isCorrect,
      wrongReasonTag: wrongReasonTag,
    );
  }

  ReportJsonMap toJson() {
    return <String, Object?>{
      'questionId': questionId,
      'skill': skill.dbValue,
      'typeTag': typeTag,
      'isCorrect': isCorrect,
      if (wrongReasonTag != null) 'wrongReasonTag': wrongReasonTag!.dbValue,
    };
  }
}

void _validateAllowedKeys(
  ReportJsonMap json,
  Set<String> allowedKeys, {
  required String path,
}) {
  for (final key in json.keys) {
    if (allowedKeys.contains(key)) {
      continue;
    }
    throw FormatException('Unexpected key "$key" at "$path".');
  }
}

void _validateIntRange(
  int value, {
  required int min,
  required int max,
  required String path,
}) {
  if (value < min || value > max) {
    throw FormatException('Expected "$path" to be between $min and $max.');
  }
}

ReportJsonMap _readRequiredObject(
  ReportJsonMap json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field "$path".');
  }
  return _asObject(json[key], path: path);
}

List<Object?> _readRequiredArray(
  ReportJsonMap json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field "$path".');
  }
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('Expected "$path" to be a JSON array.');
  }
  return value;
}

String _readRequiredString(
  ReportJsonMap json,
  String key, {
  required String path,
  required int maxLength,
}) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field "$path".');
  }
  final value = json[key];
  if (value is! String) {
    throw FormatException('Expected "$path" to be a string.');
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Expected "$path" to be non-empty.');
  }
  if (trimmed.length > maxLength) {
    throw FormatException('Expected "$path" length <= $maxLength.');
  }
  return trimmed;
}

String? _readOptionalString(
  ReportJsonMap json,
  String key, {
  required String path,
  required int maxLength,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected "$path" to be a string when present.');
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Expected "$path" to be non-empty when present.');
  }
  if (trimmed.length > maxLength) {
    throw FormatException('Expected "$path" length <= $maxLength.');
  }
  return trimmed;
}

int _readRequiredInt(ReportJsonMap json, String key, {required String path}) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field "$path".');
  }
  return _readIntValue(json[key], path: path);
}

int _readIntValue(Object? value, {required String path}) {
  if (value is int) {
    return value;
  }
  if (value is num && value == value.toInt()) {
    return value.toInt();
  }
  throw FormatException('Expected "$path" to be an integer.');
}

bool _readRequiredBool(ReportJsonMap json, String key, {required String path}) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing required field "$path".');
  }
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Expected "$path" to be a boolean.');
  }
  return value;
}

ReportJsonMap _asObject(Object? value, {required String path}) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('Expected "$path" to be a JSON object.');
  }

  final output = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.trim().isEmpty) {
      throw FormatException('Expected all keys in "$path" to be strings.');
    }
    output[key] = entry.value;
  }
  return output;
}
