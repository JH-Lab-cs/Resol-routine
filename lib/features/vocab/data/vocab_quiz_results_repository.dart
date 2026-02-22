import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/security/hidden_unicode.dart';
import '../../../core/time/day_key.dart';

class VocabQuizDailyResult {
  const VocabQuizDailyResult({
    required this.dayKey,
    required this.track,
    required this.totalCount,
    required this.correctCount,
    required this.wrongVocabIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String dayKey;
  final Track track;
  final int totalCount;
  final int correctCount;
  final List<String> wrongVocabIds;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class VocabQuizResultsRepository {
  const VocabQuizResultsRepository({required AppDatabase database})
    : _database = database;

  static const int _maxCount = 20;
  static const int _expectedTotalCount = 20;

  final AppDatabase _database;

  Future<void> upsertDailyResult({
    required String dayKey,
    required String track,
    required int totalCount,
    required int correctCount,
    required List<String> wrongVocabIds,
  }) async {
    validateDayKey(dayKey);
    final parsedTrack = trackFromDb(track);

    _validateTotalCount(totalCount, path: 'totalCount');
    _validateCount(correctCount, path: 'correctCount');
    if (correctCount > totalCount) {
      throw const FormatException('correctCount must be <= totalCount.');
    }
    final wrongCount = totalCount - correctCount;

    final normalizedWrongVocabIds = _normalizeWrongVocabIds(
      wrongVocabIds,
      path: 'wrongVocabIds',
    );
    if (normalizedWrongVocabIds.length != wrongCount) {
      throw const FormatException(
        'wrongVocabIds length must equal wrongCount.',
      );
    }
    await _validateAllVocabIdsExist(normalizedWrongVocabIds);

    final wrongVocabIdsJson = jsonEncode(normalizedWrongVocabIds);
    if (wrongVocabIdsJson.length > DbTextLimits.vocabWrongVocabIdsJsonMax) {
      throw FormatException(
        'wrongVocabIdsJson length must be <= ${DbTextLimits.vocabWrongVocabIdsJsonMax}.',
      );
    }

    final parsedDayKey = int.parse(dayKey);
    final now = DateTime.now().toUtc();

    await _database.transaction(() async {
      final existing =
          await (_database.select(_database.vocabQuizResults)..where((tbl) {
                return tbl.dayKey.equals(parsedDayKey) &
                    tbl.track.equals(parsedTrack.dbValue);
              }))
              .getSingleOrNull();

      if (existing == null) {
        await _database
            .into(_database.vocabQuizResults)
            .insert(
              VocabQuizResultsCompanion.insert(
                dayKey: parsedDayKey,
                track: parsedTrack.dbValue,
                totalCount: totalCount,
                correctCount: correctCount,
                wrongVocabIdsJson: wrongVocabIdsJson,
                updatedAt: Value(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.vocabQuizResults,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        VocabQuizResultsCompanion(
          totalCount: Value(totalCount),
          correctCount: Value(correctCount),
          wrongVocabIdsJson: Value(wrongVocabIdsJson),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<VocabQuizDailyResult?> loadByDayKey({
    required String dayKey,
    required String track,
  }) async {
    validateDayKey(dayKey);
    final parsedTrack = trackFromDb(track);
    final parsedDayKey = int.parse(dayKey);

    final row =
        await (_database.select(_database.vocabQuizResults)..where((tbl) {
              return tbl.dayKey.equals(parsedDayKey) &
                  tbl.track.equals(parsedTrack.dbValue);
            }))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    final wrongVocabIds = _decodeWrongVocabIds(
      row.wrongVocabIdsJson,
      path: 'vocabQuizResults[$parsedDayKey].wrongVocabIdsJson',
    );
    _validateTotalCount(row.totalCount, path: 'totalCount');
    _validateCount(row.correctCount, path: 'correctCount');
    if (row.correctCount > row.totalCount) {
      throw const FormatException('correctCount must be <= totalCount.');
    }
    final wrongCount = row.totalCount - row.correctCount;
    if (wrongVocabIds.length != wrongCount) {
      throw const FormatException(
        'wrongVocabIds length must equal wrongCount.',
      );
    }

    return VocabQuizDailyResult(
      dayKey: dayKey,
      track: parsedTrack,
      totalCount: row.totalCount,
      correctCount: row.correctCount,
      wrongVocabIds: List<String>.unmodifiable(wrongVocabIds),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  List<String> _decodeWrongVocabIds(String rawJson, {required String path}) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List<Object?>) {
      throw FormatException('Expected "$path" to be a JSON array.');
    }

    final ids = <String>[];
    for (var i = 0; i < decoded.length; i++) {
      final value = decoded[i];
      if (value is! String) {
        throw FormatException('Expected "$path[$i]" to be a string.');
      }
      ids.add(value);
    }

    return _normalizeWrongVocabIds(ids, path: path);
  }

  List<String> _normalizeWrongVocabIds(
    List<String> wrongVocabIds, {
    required String path,
  }) {
    final seen = <String>{};
    final normalized = <String>[];

    for (var i = 0; i < wrongVocabIds.length; i++) {
      final raw = wrongVocabIds[i].trim();
      if (raw.isEmpty) {
        throw FormatException('Expected "$path[$i]" to be non-empty.');
      }
      if (raw.length > DbTextLimits.idMax) {
        throw FormatException(
          'Expected "$path[$i]" length <= ${DbTextLimits.idMax}.',
        );
      }
      validateNoHiddenUnicode(raw, path: '$path[$i]');
      if (!seen.add(raw)) {
        throw FormatException('Duplicated value at "$path[$i]".');
      }
      normalized.add(raw);
    }

    normalized.sort();
    if (normalized.length > _maxCount) {
      throw const FormatException('wrongVocabIds length must be <= 20.');
    }

    return normalized;
  }

  Future<void> _validateAllVocabIdsExist(List<String> vocabIds) async {
    if (vocabIds.isEmpty) {
      return;
    }

    final rows = await (_database.select(
      _database.vocabMaster,
    )..where((tbl) => tbl.id.isIn(vocabIds))).get();
    final existingIds = <String>{for (final row in rows) row.id};
    for (var i = 0; i < vocabIds.length; i++) {
      if (existingIds.contains(vocabIds[i])) {
        continue;
      }
      throw FormatException(
        'Expected "wrongVocabIds[$i]" to reference an existing vocab id.',
      );
    }
  }

  void _validateCount(int value, {required String path}) {
    if (value < 0 || value > _maxCount) {
      throw FormatException('$path must be between 0 and $_maxCount.');
    }
  }

  void _validateTotalCount(int value, {required String path}) {
    if (value != _expectedTotalCount) {
      throw FormatException('$path must be exactly $_expectedTotalCount.');
    }
  }
}
