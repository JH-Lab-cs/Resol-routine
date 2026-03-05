import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/security/hidden_unicode.dart';

class VocabLemmaRepository {
  const VocabLemmaRepository({required AppDatabase database})
    : _database = database;

  static const int _sqliteInChunkSize = 900;
  static const int _maxLookupIds = 2000;
  static const int _maxRawLookupIds = _maxLookupIds * 3;

  final AppDatabase _database;

  Future<Map<String, String>> loadLemmaMapByVocabIds(List<String> ids) async {
    _validateRawInputSize(ids.length);
    final normalizedIds = _normalizeIds(ids);
    _validateDedupedInputSize(normalizedIds.length);
    if (normalizedIds.isEmpty) {
      return const <String, String>{};
    }

    final loadedLemmas = <String, String>{};
    for (final chunk in _chunkIds(normalizedIds)) {
      final rows = await (_database.select(
        _database.vocabMaster,
      )..where((tbl) => tbl.id.isIn(chunk))).get();
      for (final row in rows) {
        final lemma = row.lemma;
        if (containsHiddenUnicode(lemma)) {
          continue;
        }
        loadedLemmas[row.id] = lemma;
      }
    }

    // Keep insertion order deterministic based on the normalized input order.
    final ordered = <String, String>{};
    for (final id in normalizedIds) {
      final lemma = loadedLemmas[id];
      if (lemma != null) {
        ordered[id] = lemma;
      }
    }
    return ordered;
  }

  List<String> _normalizeIds(List<String> ids) {
    final normalized = <String>[];
    final seen = <String>{};

    for (var i = 0; i < ids.length; i++) {
      final value = ids[i].trim();
      if (value.isEmpty) {
        throw FormatException('Expected "ids[$i]" to be non-empty.');
      }
      if (value.length > DbTextLimits.idMax) {
        throw FormatException(
          'Expected "ids[$i]" length <= ${DbTextLimits.idMax}.',
        );
      }
      validateNoHiddenUnicode(value, path: 'ids[$i]');
      if (seen.add(value)) {
        normalized.add(value);
      }
    }
    return normalized;
  }

  Iterable<List<String>> _chunkIds(List<String> ids) sync* {
    for (var index = 0; index < ids.length; index += _sqliteInChunkSize) {
      final end = index + _sqliteInChunkSize > ids.length
          ? ids.length
          : index + _sqliteInChunkSize;
      yield ids.sublist(index, end);
    }
  }

  void _validateRawInputSize(int length) {
    if (length > _maxRawLookupIds) {
      throw FormatException('Expected "ids" length <= $_maxRawLookupIds.');
    }
  }

  void _validateDedupedInputSize(int length) {
    if (length > _maxLookupIds) {
      throw FormatException(
        'Expected deduplicated "ids" length <= $_maxLookupIds.',
      );
    }
  }
}
