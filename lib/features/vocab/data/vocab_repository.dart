import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/time/day_key.dart';

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

class VocabQuizQuestion {
  const VocabQuizQuestion({
    required this.vocabId,
    required this.lemma,
    required this.correctMeaning,
    required this.options,
    required this.correctOptionIndex,
  });

  final String vocabId;
  final String lemma;
  final String correctMeaning;
  final List<String> options;
  final int correctOptionIndex;
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

  Future<void> addVocabulary({
    required String lemma,
    required String meaning,
    String? pos,
    String? example,
  }) async {
    final normalizedLemma = lemma.trim();
    final normalizedMeaning = meaning.trim();
    final normalizedPos = pos?.trim();
    final normalizedExample = example?.trim();

    if (normalizedLemma.isEmpty) {
      throw const FormatException('단어를 입력해 주세요.');
    }
    if (normalizedMeaning.isEmpty) {
      throw const FormatException('뜻을 입력해 주세요.');
    }
    if (normalizedLemma.length > DbTextLimits.lemmaMax) {
      throw const FormatException('단어 길이가 너무 깁니다.');
    }
    if (normalizedMeaning.length > DbTextLimits.meaningMax) {
      throw const FormatException('뜻 길이가 너무 깁니다.');
    }

    final vocabId = 'user_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await _database
        .into(_database.vocabMaster)
        .insert(
          VocabMasterCompanion.insert(
            id: vocabId,
            lemma: normalizedLemma,
            meaning: normalizedMeaning,
            pos: Value(
              normalizedPos == null || normalizedPos.isEmpty
                  ? null
                  : normalizedPos,
            ),
            example: Value(
              normalizedExample == null || normalizedExample.isEmpty
                  ? null
                  : normalizedExample,
            ),
          ),
        );
  }

  Future<List<VocabListItem>> listMyVocabulary({String searchTerm = ''}) async {
    final allItems = await listVocabulary(searchTerm: searchTerm);
    return allItems
        .where((item) => item.id.startsWith('user_') || item.isBookmarked)
        .toList(growable: false);
  }

  Future<List<VocabListItem>> listTodayVocabulary({
    String searchTerm = '',
    DateTime? nowLocal,
    int count = 20,
  }) async {
    final questions = await loadTodayQuizQuestions(
      nowLocal: nowLocal,
      count: count,
    );
    if (questions.isEmpty) {
      return const <VocabListItem>[];
    }

    final allItems = await listVocabulary();
    final byId = <String, VocabListItem>{
      for (final item in allItems) item.id: item,
    };

    final orderedUniqueIds = <String>[];
    final seen = <String>{};
    for (final question in questions) {
      if (seen.add(question.vocabId)) {
        orderedUniqueIds.add(question.vocabId);
      }
    }

    final filtered = <VocabListItem>[];
    final keyword = searchTerm.trim().toLowerCase();
    final hasKeyword = keyword.isNotEmpty;
    for (final id in orderedUniqueIds) {
      final item = byId[id];
      if (item == null) {
        continue;
      }
      if (hasKeyword && !item.lemma.toLowerCase().contains(keyword)) {
        continue;
      }
      filtered.add(item);
    }
    return filtered;
  }

  Future<List<VocabQuizQuestion>> loadTodayQuizQuestions({
    DateTime? nowLocal,
    int count = 20,
  }) async {
    final allItems = await listVocabulary();
    if (allItems.isEmpty) {
      return const <VocabQuizQuestion>[];
    }

    final dayKey = formatDayKey(nowLocal ?? DateTime.now());
    validateDayKey(dayKey);

    final scoredItems =
        <_ScoredVocab>[
          for (final item in allItems)
            _ScoredVocab(
              item: item,
              score: _fnv1a32('$dayKey|quiz|${item.id}'),
            ),
        ]..sort((a, b) {
          final byScore = a.score.compareTo(b.score);
          if (byScore != 0) {
            return byScore;
          }
          return a.item.id.compareTo(b.item.id);
        });

    final selectedItems = <VocabListItem>[];
    for (var i = 0; i < count; i++) {
      selectedItems.add(scoredItems[i % scoredItems.length].item);
    }

    return selectedItems
        .map(
          (item) => _buildQuizQuestion(
            dayKey: dayKey,
            item: item,
            allItems: allItems,
          ),
        )
        .toList(growable: false);
  }

  VocabQuizQuestion _buildQuizQuestion({
    required String dayKey,
    required VocabListItem item,
    required List<VocabListItem> allItems,
  }) {
    final distractorPool =
        allItems
            .where((candidate) => candidate.id != item.id)
            .map((candidate) => candidate.meaning)
            .where((meaning) => meaning != item.meaning)
            .toSet()
            .toList(growable: false)
          ..sort(
            (a, b) => _fnv1a32(
              '$dayKey|${item.id}|distractor|$a',
            ).compareTo(_fnv1a32('$dayKey|${item.id}|distractor|$b')),
          );

    final distractors = <String>[];
    for (final meaning in distractorPool) {
      if (distractors.length == 4) {
        break;
      }
      distractors.add(meaning);
    }
    while (distractors.length < 4) {
      distractors.add('선택지 ${distractors.length + 1}');
    }

    final options = <String>[item.meaning, ...distractors]
      ..sort(
        (a, b) => _fnv1a32(
          '$dayKey|${item.id}|option|$a',
        ).compareTo(_fnv1a32('$dayKey|${item.id}|option|$b')),
      );
    final correctOptionIndex = options.indexOf(item.meaning);

    return VocabQuizQuestion(
      vocabId: item.id,
      lemma: item.lemma,
      correctMeaning: item.meaning,
      options: options,
      correctOptionIndex: correctOptionIndex < 0 ? 0 : correctOptionIndex,
    );
  }
}

class _ScoredVocab {
  const _ScoredVocab({required this.item, required this.score});

  final VocabListItem item;
  final int score;
}

int _fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}
