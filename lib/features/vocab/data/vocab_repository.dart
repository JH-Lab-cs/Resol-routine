import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/security/hidden_unicode.dart';
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

  static const String _customVocabPrefix = 'user_';
  static final Random _idRandom = Random.secure();

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
          'WHERE vm.deleted_at IS NULL '
          'AND (? = 0 OR LOWER(vm.lemma) LIKE ?) '
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
    final normalized = _validateAndNormalizeInput(
      lemma: lemma,
      meaning: meaning,
      pos: pos,
      example: example,
    );
    final vocabId = _buildCustomVocabId();

    await _database
        .into(_database.vocabMaster)
        .insert(
          VocabMasterCompanion.insert(
            id: vocabId,
            lemma: normalized.lemma,
            meaning: normalized.meaning,
            pos: Value(normalized.pos),
            example: Value(normalized.example),
          ),
        );
  }

  Future<void> updateVocabulary({
    required String id,
    required String lemma,
    required String meaning,
    String? pos,
    String? example,
  }) async {
    final normalizedId = _validateCustomVocabId(id, actionVerb: '수정');
    final targetRow = await (_database.select(
      _database.vocabMaster,
    )..where((tbl) => tbl.id.equals(normalizedId))).getSingleOrNull();
    if (targetRow == null) {
      throw const FormatException('수정할 단어를 찾지 못했습니다.');
    }
    if (targetRow.deletedAt != null) {
      throw const FormatException('삭제된 단어는 수정할 수 없습니다.');
    }

    final normalized = _validateAndNormalizeInput(
      lemma: lemma,
      meaning: meaning,
      pos: pos,
      example: example,
    );

    final updatedRows =
        await (_database.update(_database.vocabMaster)..where(
              (tbl) => tbl.id.equals(normalizedId) & tbl.deletedAt.isNull(),
            ))
            .write(
              VocabMasterCompanion(
                lemma: Value(normalized.lemma),
                meaning: Value(normalized.meaning),
                pos: Value(normalized.pos),
                example: Value(normalized.example),
              ),
            );
    if (updatedRows == 0) {
      throw const FormatException('수정할 단어를 찾지 못했습니다.');
    }
  }

  Future<bool> deleteVocabulary({required String id}) async {
    final normalizedId = _validateCustomVocabId(id, actionVerb: '삭제');
    return _database.transaction(() async {
      final existingRow = await (_database.select(
        _database.vocabMaster,
      )..where((tbl) => tbl.id.equals(normalizedId))).getSingleOrNull();
      if (existingRow == null || existingRow.deletedAt != null) {
        return false;
      }

      await (_database.delete(
        _database.vocabUser,
      )..where((tbl) => tbl.vocabId.equals(normalizedId))).go();

      final updatedRows =
          await (_database.update(_database.vocabMaster)..where(
                (tbl) => tbl.id.equals(normalizedId) & tbl.deletedAt.isNull(),
              ))
              .write(
                VocabMasterCompanion(deletedAt: Value(DateTime.now().toUtc())),
              );

      return updatedRows > 0;
    });
  }

  Future<List<VocabListItem>> listMyVocabulary({String searchTerm = ''}) async {
    final allItems = await listVocabulary(searchTerm: searchTerm);
    return allItems
        .where(
          (item) => item.id.startsWith(_customVocabPrefix) || item.isBookmarked,
        )
        .toList(growable: false);
  }

  Future<List<VocabListItem>> listTodayVocabulary({
    String searchTerm = '',
    DateTime? nowLocal,
    int count = 20,
  }) async {
    final questions = await buildQuiz(nowLocal: nowLocal, count: count);
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

  Future<List<VocabQuizQuestion>> buildQuiz({
    DateTime? nowLocal,
    int count = 20,
  }) async {
    if (count <= 0) {
      return const <VocabQuizQuestion>[];
    }

    final allItems = await listVocabulary();
    if (allItems.isEmpty) {
      return const <VocabQuizQuestion>[];
    }

    final dayKey = formatDayKey(nowLocal ?? DateTime.now());
    validateDayKey(dayKey);

    final scoredItems = _sortByDeterministicScore(allItems, dayKey: dayKey);
    final prioritizedPool = _prioritizeCustomBookmarked(scoredItems);
    final selectedUniqueItems = _selectUniqueQuizItems(
      prioritizedPool,
      count: count,
    );
    final selectedItems = _expandQuizItemsIfNeeded(
      selectedUniqueItems,
      count: count,
    );

    if (selectedItems.isEmpty) {
      return const <VocabQuizQuestion>[];
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

  Future<List<VocabQuizQuestion>> loadTodayQuizQuestions({
    DateTime? nowLocal,
    int count = 20,
  }) {
    return buildQuiz(nowLocal: nowLocal, count: count);
  }

  List<VocabListItem> _sortByDeterministicScore(
    List<VocabListItem> allItems, {
    required String dayKey,
  }) {
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
    return scoredItems.map((scored) => scored.item).toList(growable: false);
  }

  List<VocabListItem> _prioritizeCustomBookmarked(List<VocabListItem> items) {
    final customBookmarked = <VocabListItem>[];
    final others = <VocabListItem>[];

    for (final item in items) {
      if (item.id.startsWith(_customVocabPrefix) && item.isBookmarked) {
        customBookmarked.add(item);
      } else {
        others.add(item);
      }
    }

    return <VocabListItem>[...customBookmarked, ...others];
  }

  List<VocabListItem> _selectUniqueQuizItems(
    List<VocabListItem> prioritizedPool, {
    required int count,
  }) {
    final selected = <VocabListItem>[];
    final selectedIds = <String>{};
    final selectedMeanings = <String>{};

    for (final item in prioritizedPool) {
      if (selected.length == count) {
        break;
      }
      if (!selectedIds.add(item.id)) {
        continue;
      }
      if (!selectedMeanings.add(item.meaning)) {
        continue;
      }
      selected.add(item);
    }

    if (selected.length == count) {
      return selected;
    }

    for (final item in prioritizedPool) {
      if (selected.length == count) {
        break;
      }
      if (!selectedIds.add(item.id)) {
        continue;
      }
      selected.add(item);
    }

    return selected;
  }

  List<VocabListItem> _expandQuizItemsIfNeeded(
    List<VocabListItem> selectedItems, {
    required int count,
  }) {
    if (selectedItems.length >= count) {
      return selectedItems.sublist(0, count);
    }
    if (selectedItems.isEmpty) {
      return const <VocabListItem>[];
    }

    final expanded = List<VocabListItem>.from(selectedItems);
    for (
      var index = 0;
      expanded.length < count;
      index = (index + 1) % selectedItems.length
    ) {
      expanded.add(selectedItems[index]);
    }
    return expanded;
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
    final existingOptions = <String>{item.meaning, ...distractors};
    while (distractors.length < 4) {
      final placeholder = _buildPlaceholderOption(
        startingNumber: distractors.length + 1,
        existingOptions: existingOptions,
      );
      distractors.add(placeholder);
      existingOptions.add(placeholder);
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

  String _buildPlaceholderOption({
    required int startingNumber,
    required Set<String> existingOptions,
  }) {
    var candidateNumber = startingNumber;
    while (true) {
      final candidate = '선택지 $candidateNumber';
      if (!existingOptions.contains(candidate)) {
        return candidate;
      }
      candidateNumber += 1;
    }
  }

  _NormalizedVocabularyInput _validateAndNormalizeInput({
    required String lemma,
    required String meaning,
    String? pos,
    String? example,
  }) {
    final normalizedLemma = lemma.trim();
    final normalizedMeaning = meaning.trim();
    final normalizedPos = _normalizeOptionalField(
      value: pos,
      path: 'pos',
      maxLength: DbTextLimits.lemmaMax,
      lengthErrorMessage: '품사 길이가 너무 깁니다.',
      hiddenUnicodeErrorMessage: '품사에 허용되지 않는 문자가 포함되어 있습니다.',
    );
    final normalizedExample = _normalizeOptionalField(
      value: example,
      path: 'example',
      maxLength: DbTextLimits.meaningMax,
      lengthErrorMessage: '예문 길이가 너무 깁니다.',
      hiddenUnicodeErrorMessage: '예문에 허용되지 않는 문자가 포함되어 있습니다.',
    );

    _validateRequiredField(
      value: normalizedLemma,
      path: 'lemma',
      emptyErrorMessage: '단어를 입력해 주세요.',
      lengthErrorMessage: '단어 길이가 너무 깁니다.',
      hiddenUnicodeErrorMessage: '단어에 허용되지 않는 문자가 포함되어 있습니다.',
      maxLength: DbTextLimits.lemmaMax,
    );
    _validateRequiredField(
      value: normalizedMeaning,
      path: 'meaning',
      emptyErrorMessage: '뜻을 입력해 주세요.',
      lengthErrorMessage: '뜻 길이가 너무 깁니다.',
      hiddenUnicodeErrorMessage: '뜻에 허용되지 않는 문자가 포함되어 있습니다.',
      maxLength: DbTextLimits.meaningMax,
    );

    return _NormalizedVocabularyInput(
      lemma: normalizedLemma,
      meaning: normalizedMeaning,
      pos: normalizedPos,
      example: normalizedExample,
    );
  }

  void _validateRequiredField({
    required String value,
    required String path,
    required String emptyErrorMessage,
    required String lengthErrorMessage,
    required String hiddenUnicodeErrorMessage,
    required int maxLength,
  }) {
    if (value.isEmpty) {
      throw FormatException(emptyErrorMessage);
    }
    if (value.length > maxLength) {
      throw FormatException(lengthErrorMessage);
    }
    _validateNoHiddenUnicode(
      value,
      path: path,
      errorMessage: hiddenUnicodeErrorMessage,
    );
  }

  String? _normalizeOptionalField({
    required String? value,
    required String path,
    required int maxLength,
    required String lengthErrorMessage,
    required String hiddenUnicodeErrorMessage,
  }) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length > maxLength) {
      throw FormatException(lengthErrorMessage);
    }
    _validateNoHiddenUnicode(
      normalized,
      path: path,
      errorMessage: hiddenUnicodeErrorMessage,
    );
    return normalized;
  }

  void _validateNoHiddenUnicode(
    String value, {
    required String path,
    required String errorMessage,
  }) {
    try {
      validateNoHiddenUnicode(value, path: path);
    } on FormatException {
      throw FormatException(errorMessage);
    }
  }

  String _buildCustomVocabId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final randomToken = _idRandom
        .nextInt(0x1000000)
        .toRadixString(16)
        .padLeft(6, '0');
    final id = '$_customVocabPrefix${millis}_$randomToken';
    if (id.length > DbTextLimits.idMax) {
      throw const FormatException('단어 ID를 생성하지 못했습니다.');
    }
    return id;
  }

  String _validateCustomVocabId(String id, {required String actionVerb}) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || normalizedId.length > DbTextLimits.idMax) {
      throw const FormatException('유효하지 않은 단어 ID입니다.');
    }
    _validateNoHiddenUnicode(
      normalizedId,
      path: 'id',
      errorMessage: '유효하지 않은 단어 ID입니다.',
    );
    if (!normalizedId.startsWith(_customVocabPrefix)) {
      throw FormatException('직접 추가한 단어만 $actionVerb할 수 있습니다.');
    }
    return normalizedId;
  }
}

class _NormalizedVocabularyInput {
  const _NormalizedVocabularyInput({
    required this.lemma,
    required this.meaning,
    required this.pos,
    required this.example,
  });

  final String lemma;
  final String meaning;
  final String? pos;
  final String? example;
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
