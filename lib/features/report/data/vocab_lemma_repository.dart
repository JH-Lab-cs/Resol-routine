import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/security/hidden_unicode.dart';

class VocabLemmaRepository {
  const VocabLemmaRepository({required AppDatabase database})
    : _database = database;

  final AppDatabase _database;

  Future<Map<String, String>> loadLemmaMapByVocabIds(List<String> ids) async {
    final normalizedIds = _normalizeIds(ids);
    if (normalizedIds.isEmpty) {
      return const <String, String>{};
    }

    final rows = await (_database.select(
      _database.vocabMaster,
    )..where((tbl) => tbl.id.isIn(normalizedIds))).get();
    return <String, String>{for (final row in rows) row.id: row.lemma};
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
}
