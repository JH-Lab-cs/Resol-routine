import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class VocabListItem {
  const VocabListItem({
    required this.id,
    required this.lemma,
    required this.meaning,
    required this.example,
    required this.pos,
    required this.isBookmarked,
  });

  final String id;
  final String lemma;
  final String meaning;
  final String? example;
  final String? pos;
  final bool isBookmarked;
}

class VocabRepository {
  const VocabRepository({required AppDatabase database}) : _database = database;

  final AppDatabase _database;

  Future<List<VocabListItem>> listVocabulary({String searchTerm = ''}) async {
    final normalized = searchTerm.trim().toLowerCase();

    final hasKeyword = normalized.isNotEmpty;
    final rows = await _database
        .customSelect(
          'SELECT '
          'vm.id AS id, '
          'vm.lemma AS lemma, '
          'vm.meaning AS meaning, '
          'vm.example AS example, '
          'vm.pos AS pos, '
          'COALESCE(vu.is_bookmarked, 0) AS is_bookmarked '
          'FROM vocab_master vm '
          'LEFT JOIN vocab_user vu ON vu.vocab_id = vm.id '
          'WHERE (? = 0 OR LOWER(vm.lemma) LIKE ?) '
          'ORDER BY vm.lemma ASC',
          variables: [
            Variable<int>(hasKeyword ? 1 : 0),
            Variable<String>('%$normalized%'),
          ],
          readsFrom: {_database.vocabMaster, _database.vocabUser},
        )
        .get();

    return rows
        .map(
          (row) => VocabListItem(
            id: row.read<String>('id'),
            lemma: row.read<String>('lemma'),
            meaning: row.read<String>('meaning'),
            example: row.read<String?>('example'),
            pos: row.read<String?>('pos'),
            isBookmarked: row.read<int>('is_bookmarked') == 1,
          ),
        )
        .toList(growable: false);
  }

  Future<void> toggleBookmark(String vocabId) async {
    await _database.transaction(() async {
      final existing = await (_database.select(
        _database.vocabUser,
      )..where((tbl) => tbl.vocabId.equals(vocabId))).getSingleOrNull();

      if (existing == null) {
        await _database
            .into(_database.vocabUser)
            .insert(
              VocabUserCompanion.insert(
                vocabId: vocabId,
                isBookmarked: const Value(true),
              ),
            );
        return;
      }

      await (_database.update(
        _database.vocabUser,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        VocabUserCompanion(
          isBookmarked: Value(!existing.isBookmarked),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }
}
