import 'dart:convert';

import '../../../../core/database/converters/json_models.dart';
import '../../../../core/database/db_text_limits.dart';

const Set<String> _allowedSkills = <String>{'LISTENING', 'READING'};
const Set<String> _allowedTracks = <String>{'M3', 'H1', 'H2', 'H3'};

class SeedLimits {
  const SeedLimits({
    this.maxJsonBytes = 10 * 1024 * 1024,
    this.maxScripts = 2000,
    this.maxPassages = 2000,
    this.maxQuestions = 10000,
    this.maxVocabulary = 30000,
    this.maxSentencesPerScript = 200,
    this.maxTurnsPerScript = 200,
    this.maxSentencesPerPassage = 200,
    this.maxSentenceTextLen = 600,
    this.maxPromptLen = DbTextLimits.promptMax,
    this.maxOptionTextLen = 220,
    this.maxWhyCorrectKoLen = DbTextLimits.whyCorrectKoMax,
    this.maxWhyWrongKoLen = 1500,
  });

  final int maxJsonBytes;
  final int maxScripts;
  final int maxPassages;
  final int maxQuestions;
  final int maxVocabulary;
  final int maxSentencesPerScript;
  final int maxTurnsPerScript;
  final int maxSentencesPerPassage;
  final int maxSentenceTextLen;
  final int maxPromptLen;
  final int maxOptionTextLen;
  final int maxWhyCorrectKoLen;
  final int maxWhyWrongKoLen;
}

class SeedContentPack {
  const SeedContentPack({
    required this.id,
    required this.version,
    required this.locale,
    required this.title,
    required this.description,
    required this.checksum,
    required this.scripts,
    required this.passages,
    required this.questions,
    required this.vocabulary,
  });

  final String id;
  final int version;
  final String locale;
  final String title;
  final String? description;
  final String checksum;
  final List<SeedScript> scripts;
  final List<SeedPassage> passages;
  final List<SeedQuestion> questions;
  final List<SeedVocabItem> vocabulary;

  static SeedContentPack parse(
    String rawJson, {
    SeedLimits limits = const SeedLimits(),
  }) {
    final jsonByteLength = utf8.encode(rawJson).length;
    if (jsonByteLength > limits.maxJsonBytes) {
      throw FormatException(
        'Content pack JSON exceeds maxJsonBytes '
        '(${limits.maxJsonBytes}): $jsonByteLength bytes.',
      );
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! JsonMap) {
      throw const FormatException(
        'The content pack root must be a JSON object.',
      );
    }

    return SeedContentPack.fromJson(decoded, limits: limits);
  }

  factory SeedContentPack.fromJson(
    JsonMap json, {
    SeedLimits limits = const SeedLimits(),
  }) {
    final packJson = _readMap(json, 'pack');

    final scriptsJson = _readList(json, 'scripts');
    _assertCollectionLimit(
      collectionPath: 'scripts',
      length: scriptsJson.length,
      maxLength: limits.maxScripts,
      maxName: 'maxScripts',
    );

    final passagesJson = _readList(json, 'passages');
    _assertCollectionLimit(
      collectionPath: 'passages',
      length: passagesJson.length,
      maxLength: limits.maxPassages,
      maxName: 'maxPassages',
    );

    final questionsJson = _readList(json, 'questions');
    _assertCollectionLimit(
      collectionPath: 'questions',
      length: questionsJson.length,
      maxLength: limits.maxQuestions,
      maxName: 'maxQuestions',
    );

    final vocabularyJson = _readList(json, 'vocabulary');
    _assertCollectionLimit(
      collectionPath: 'vocabulary',
      length: vocabularyJson.length,
      maxLength: limits.maxVocabulary,
      maxName: 'maxVocabulary',
    );

    final scripts = <SeedScript>[];
    for (var i = 0; i < scriptsJson.length; i++) {
      scripts.add(
        SeedScript.fromJson(
          _readMapFromDynamic(scriptsJson[i], 'scripts[$i]'),
          path: 'scripts[$i]',
          limits: limits,
        ),
      );
    }

    final passages = <SeedPassage>[];
    for (var i = 0; i < passagesJson.length; i++) {
      passages.add(
        SeedPassage.fromJson(
          _readMapFromDynamic(passagesJson[i], 'passages[$i]'),
          path: 'passages[$i]',
          limits: limits,
        ),
      );
    }

    final questions = <SeedQuestion>[];
    for (var i = 0; i < questionsJson.length; i++) {
      questions.add(
        SeedQuestion.fromJson(
          _readMapFromDynamic(questionsJson[i], 'questions[$i]'),
          path: 'questions[$i]',
          limits: limits,
        ),
      );
    }

    final vocabulary = <SeedVocabItem>[];
    for (var i = 0; i < vocabularyJson.length; i++) {
      vocabulary.add(
        SeedVocabItem.fromJson(
          _readMapFromDynamic(vocabularyJson[i], 'vocabulary[$i]'),
          path: 'vocabulary[$i]',
        ),
      );
    }

    final seedPack = SeedContentPack(
      id: _readString(
        packJson,
        'id',
        parentPath: 'pack',
        maxLength: DbTextLimits.idMax,
      ),
      version: _readInt(packJson, 'version', parentPath: 'pack'),
      locale: _readString(
        packJson,
        'locale',
        parentPath: 'pack',
        maxLength: DbTextLimits.localeMax,
      ),
      title: _readString(
        packJson,
        'title',
        parentPath: 'pack',
        maxLength: DbTextLimits.titleMax,
      ),
      description: _readNullableString(
        packJson,
        'description',
        parentPath: 'pack',
      ),
      checksum: _readString(
        packJson,
        'checksum',
        parentPath: 'pack',
        maxLength: DbTextLimits.checksumMax,
      ),
      scripts: scripts,
      passages: passages,
      questions: questions,
      vocabulary: vocabulary,
    );

    seedPack._validateCrossReferences();

    return seedPack;
  }

  void _validateCrossReferences() {
    _ensureUniqueIds(scripts.map((SeedScript script) => script.id), 'scripts');
    _ensureUniqueIds(
      passages.map((SeedPassage passage) => passage.id),
      'passages',
    );
    _ensureUniqueIds(
      questions.map((SeedQuestion question) => question.id),
      'questions',
    );
    _ensureUniqueIds(
      vocabulary.map((SeedVocabItem vocab) => vocab.id),
      'vocabulary',
    );

    final scriptById = <String, SeedScript>{
      for (final script in scripts) script.id: script,
    };
    final passageById = <String, SeedPassage>{
      for (final passage in passages) passage.id: passage,
    };

    for (final question in questions) {
      final hasPassage = question.passageId != null;
      final hasScript = question.scriptId != null;
      if (hasPassage == hasScript) {
        throw FormatException(
          'Question "${question.id}" must reference exactly one of '
          'passageId or scriptId.',
        );
      }

      if (question.skill == 'LISTENING' && (!hasScript || hasPassage)) {
        throw FormatException(
          'LISTENING question "${question.id}" must set scriptId only.',
        );
      }

      if (question.skill == 'READING' && (!hasPassage || hasScript)) {
        throw FormatException(
          'READING question "${question.id}" must set passageId only.',
        );
      }

      final targetSentenceIds = <String>{};
      if (hasScript) {
        final script = scriptById[question.scriptId!];
        if (script == null) {
          throw FormatException(
            'Question "${question.id}" references missing script '
            '"${question.scriptId}".',
          );
        }
        targetSentenceIds.addAll(script.sentenceIdSet);
      }
      if (hasPassage) {
        final passage = passageById[question.passageId!];
        if (passage == null) {
          throw FormatException(
            'Question "${question.id}" references missing passage '
            '"${question.passageId}".',
          );
        }
        targetSentenceIds.addAll(passage.sentenceIdSet);
      }

      for (final evidenceId in question.explanation.evidenceSentenceIds) {
        if (!targetSentenceIds.contains(evidenceId)) {
          throw FormatException(
            'Question "${question.id}" has evidence sentence "$evidenceId" '
            'that does not exist in its referenced source.',
          );
        }
      }
    }
  }
}

class SeedScript {
  const SeedScript({
    required this.id,
    required this.order,
    required this.sentences,
    required this.turns,
    required this.ttsPlan,
  });

  final String id;
  final int order;
  final List<Sentence> sentences;
  final List<Turn> turns;
  final TtsPlan ttsPlan;

  Set<String> get sentenceIdSet =>
      sentences.map((Sentence sentence) => sentence.id).toSet();

  factory SeedScript.fromJson(
    JsonMap json, {
    required String path,
    required SeedLimits limits,
  }) {
    final sentencesJson = _readList(json, 'sentences', parentPath: path);
    if (sentencesJson.isEmpty) {
      throw FormatException(
        '"$path.sentences" must contain at least one item.',
      );
    }
    _assertCollectionLimit(
      collectionPath: '$path.sentences',
      length: sentencesJson.length,
      maxLength: limits.maxSentencesPerScript,
      maxName: 'maxSentencesPerScript',
    );

    final sentences = <Sentence>[];
    for (var i = 0; i < sentencesJson.length; i++) {
      final sentence = Sentence.fromJson(
        _readMapFromDynamic(sentencesJson[i], '$path.sentences[$i]'),
        path: '$path.sentences[$i]',
      );
      if (sentence.text.length > limits.maxSentenceTextLen) {
        throw FormatException(
          '"$path.sentences[$i].text" length exceeds maxSentenceTextLen '
          '(${limits.maxSentenceTextLen}): ${sentence.text.length}.',
        );
      }
      sentences.add(sentence);
    }
    _ensureUniqueIds(
      sentences.map((Sentence sentence) => sentence.id),
      '$path.sentences',
    );

    final sentenceIdSet = sentences
        .map((Sentence sentence) => sentence.id)
        .toSet();

    final turnsJson = _readList(json, 'turns', parentPath: path);
    if (turnsJson.isEmpty) {
      throw FormatException('"$path.turns" must contain at least one item.');
    }
    _assertCollectionLimit(
      collectionPath: '$path.turns',
      length: turnsJson.length,
      maxLength: limits.maxTurnsPerScript,
      maxName: 'maxTurnsPerScript',
    );

    final turns = <Turn>[];
    for (var i = 0; i < turnsJson.length; i++) {
      final turn = Turn.fromJson(
        _readMapFromDynamic(turnsJson[i], '$path.turns[$i]'),
        path: '$path.turns[$i]',
      );
      for (final sentenceId in turn.sentenceIds) {
        if (!sentenceIdSet.contains(sentenceId)) {
          throw FormatException(
            '"$path.turns[$i].sentenceIds" includes unknown sentence id '
            '"$sentenceId".',
          );
        }
      }
      turns.add(turn);
    }

    final ttsPlan = TtsPlan.fromJson(
      _readMap(json, 'ttsPlan', parentPath: path),
      path: '$path.ttsPlan',
    );
    _validateTtsPlan(ttsPlan, path: '$path.ttsPlan');

    return SeedScript(
      id: _readString(
        json,
        'id',
        parentPath: path,
        maxLength: DbTextLimits.idMax,
      ),
      order: _readNonNegativeInt(json, 'order', parentPath: path),
      sentences: sentences,
      turns: turns,
      ttsPlan: ttsPlan,
    );
  }
}

class SeedPassage {
  const SeedPassage({
    required this.id,
    required this.title,
    required this.order,
    required this.sentences,
  });

  final String id;
  final String? title;
  final int order;
  final List<Sentence> sentences;

  Set<String> get sentenceIdSet =>
      sentences.map((Sentence sentence) => sentence.id).toSet();

  factory SeedPassage.fromJson(
    JsonMap json, {
    required String path,
    required SeedLimits limits,
  }) {
    final sentencesJson = _readList(json, 'sentences', parentPath: path);
    if (sentencesJson.isEmpty) {
      throw FormatException(
        '"$path.sentences" must contain at least one item.',
      );
    }
    _assertCollectionLimit(
      collectionPath: '$path.sentences',
      length: sentencesJson.length,
      maxLength: limits.maxSentencesPerPassage,
      maxName: 'maxSentencesPerPassage',
    );

    final sentences = <Sentence>[];
    for (var i = 0; i < sentencesJson.length; i++) {
      final sentence = Sentence.fromJson(
        _readMapFromDynamic(sentencesJson[i], '$path.sentences[$i]'),
        path: '$path.sentences[$i]',
      );
      if (sentence.text.length > limits.maxSentenceTextLen) {
        throw FormatException(
          '"$path.sentences[$i].text" length exceeds maxSentenceTextLen '
          '(${limits.maxSentenceTextLen}): ${sentence.text.length}.',
        );
      }
      sentences.add(sentence);
    }
    _ensureUniqueIds(
      sentences.map((Sentence sentence) => sentence.id),
      '$path.sentences',
    );

    return SeedPassage(
      id: _readString(
        json,
        'id',
        parentPath: path,
        maxLength: DbTextLimits.idMax,
      ),
      title: _readNullableString(json, 'title', parentPath: path),
      order: _readNonNegativeInt(json, 'order', parentPath: path),
      sentences: sentences,
    );
  }
}

class SeedQuestion {
  const SeedQuestion({
    required this.id,
    required this.skill,
    required this.typeTag,
    required this.track,
    required this.difficulty,
    required this.passageId,
    required this.scriptId,
    required this.prompt,
    required this.options,
    required this.answerKey,
    required this.order,
    required this.explanation,
  });

  final String id;
  final String skill;
  final String typeTag;
  final String track;
  final int difficulty;
  final String? passageId;
  final String? scriptId;
  final String prompt;
  final OptionMap options;
  final String answerKey;
  final int order;
  final SeedExplanation explanation;

  factory SeedQuestion.fromJson(
    JsonMap json, {
    required String path,
    required SeedLimits limits,
  }) {
    final skill = _readEnum(
      json,
      'skill',
      allowed: _allowedSkills,
      parentPath: path,
    );

    final typeTag = _readString(
      json,
      'typeTag',
      parentPath: path,
      maxLength: DbTextLimits.typeTagMax,
    );
    if (skill == 'LISTENING' && !RegExp(r'^L\d+$').hasMatch(typeTag)) {
      throw FormatException('"$path.typeTag" must match L<digit...>.');
    }
    if (skill == 'READING' && !RegExp(r'^R\d+$').hasMatch(typeTag)) {
      throw FormatException('"$path.typeTag" must match R<digit...>.');
    }

    final options = _readOptionMap(
      json,
      'options',
      parentPath: path,
      maxValueLength: limits.maxOptionTextLen,
    );

    return SeedQuestion(
      id: _readString(
        json,
        'id',
        parentPath: path,
        maxLength: DbTextLimits.idMax,
      ),
      skill: skill,
      typeTag: typeTag,
      track: _readEnum(
        json,
        'track',
        allowed: _allowedTracks,
        parentPath: path,
      ),
      difficulty: _readRangeInt(
        json,
        'difficulty',
        min: 1,
        max: 5,
        parentPath: path,
      ),
      passageId: _readNullableString(json, 'passageId', parentPath: path),
      scriptId: _readNullableString(json, 'scriptId', parentPath: path),
      prompt: _readString(
        json,
        'prompt',
        parentPath: path,
        maxLength: _capAtDb(limits.maxPromptLen, DbTextLimits.promptMax),
      ),
      options: options,
      answerKey: _readEnum(
        json,
        'answerKey',
        allowed: optionKeys.toSet(),
        parentPath: path,
      ),
      order: _readNonNegativeInt(json, 'order', parentPath: path),
      explanation: SeedExplanation.fromJson(
        _readMap(json, 'explanation', parentPath: path),
        path: '$path.explanation',
        limits: limits,
      ),
    );
  }
}

class SeedExplanation {
  const SeedExplanation({
    required this.id,
    required this.evidenceSentenceIds,
    required this.whyCorrectKo,
    required this.whyWrongKo,
    required this.vocabNotes,
    required this.structureNotesKo,
    required this.glossKo,
  });

  final String id;
  final List<String> evidenceSentenceIds;
  final String whyCorrectKo;
  final OptionMap whyWrongKo;
  final Object? vocabNotes;
  final String? structureNotesKo;
  final Object? glossKo;

  factory SeedExplanation.fromJson(
    JsonMap json, {
    required String path,
    required SeedLimits limits,
  }) {
    final evidenceSentenceIds = _readStringList(
      json,
      'evidenceSentenceIds',
      parentPath: path,
    );
    if (evidenceSentenceIds.isEmpty) {
      throw FormatException(
        '"$path.evidenceSentenceIds" must contain at least one sentence id.',
      );
    }

    return SeedExplanation(
      id: _readString(
        json,
        'id',
        parentPath: path,
        maxLength: DbTextLimits.idMax,
      ),
      evidenceSentenceIds: evidenceSentenceIds,
      whyCorrectKo: _readString(
        json,
        'whyCorrectKo',
        parentPath: path,
        maxLength: _capAtDb(
          limits.maxWhyCorrectKoLen,
          DbTextLimits.whyCorrectKoMax,
        ),
      ),
      whyWrongKo: _readOptionMap(
        json,
        'whyWrongKo',
        parentPath: path,
        maxValueLength: limits.maxWhyWrongKoLen,
      ),
      vocabNotes: _readOptionalJsonValue(json, 'vocabNotes', parentPath: path),
      structureNotesKo: _readNullableString(
        json,
        'structureNotesKo',
        parentPath: path,
      ),
      glossKo: _readOptionalJsonValue(json, 'glossKo', parentPath: path),
    );
  }
}

class SeedVocabItem {
  const SeedVocabItem({
    required this.id,
    required this.lemma,
    required this.partOfSpeech,
    required this.meaning,
    required this.example,
    required this.ipa,
  });

  final String id;
  final String lemma;
  final String? partOfSpeech;
  final String meaning;
  final String? example;
  final String? ipa;

  factory SeedVocabItem.fromJson(JsonMap json, {required String path}) {
    return SeedVocabItem(
      id: _readString(
        json,
        'id',
        parentPath: path,
        maxLength: DbTextLimits.idMax,
      ),
      lemma: _readString(
        json,
        'lemma',
        parentPath: path,
        maxLength: DbTextLimits.lemmaMax,
      ),
      partOfSpeech: _readNullableString(json, 'pos', parentPath: path),
      meaning: _readString(
        json,
        'meaning',
        parentPath: path,
        maxLength: DbTextLimits.meaningMax,
      ),
      example: _readNullableString(json, 'example', parentPath: path),
      ipa: _readNullableString(json, 'ipa', parentPath: path),
    );
  }
}

void _validateTtsPlan(TtsPlan ttsPlan, {required String path}) {
  _validateRange(
    ttsPlan.pauseRangeMs,
    path: '$path.pauseRangeMs',
    minBound: 100.0,
    maxBound: 3000.0,
    nonNegative: true,
  );
  _validateRange(
    ttsPlan.rateRange,
    path: '$path.rateRange',
    minBound: 0.7,
    maxBound: 1.3,
    strictlyPositive: true,
  );
  _validateRange(
    ttsPlan.pitchRange,
    path: '$path.pitchRange',
    minBound: 0.0,
    maxBound: 2.0,
    nonNegative: true,
  );
}

void _validateRange(
  NumericRange range, {
  required String path,
  required double minBound,
  required double maxBound,
  bool nonNegative = false,
  bool strictlyPositive = false,
}) {
  if (nonNegative && (range.min < 0 || range.max < 0)) {
    throw FormatException('Expected "$path" values to be non-negative.');
  }

  if (strictlyPositive && (range.min <= 0 || range.max <= 0)) {
    throw FormatException('Expected "$path" values to be greater than 0.');
  }

  if (range.min < minBound) {
    throw FormatException('Expected "$path.min" to be >= $minBound.');
  }

  if (range.max > maxBound) {
    throw FormatException('Expected "$path.max" to be <= $maxBound.');
  }
}

void _assertCollectionLimit({
  required String collectionPath,
  required int length,
  required int maxLength,
  required String maxName,
}) {
  if (length > maxLength) {
    throw FormatException(
      '"$collectionPath" exceeds $maxName ($maxLength): $length.',
    );
  }
}

void _ensureUniqueIds(Iterable<String> ids, String path) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw FormatException('Duplicate id "$id" found in "$path".');
    }
  }
}

JsonMap _readMap(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Expected "$path" to be a JSON object.');
}

JsonMap _readMapFromDynamic(Object? value, String path) {
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Expected "$path" to be a JSON object.');
}

List<Object?> _readList(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('Expected "$path" to be a JSON array.');
}

String _readString(
  JsonMap map,
  String key, {
  String? parentPath,
  int? maxLength,
}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    if (maxLength != null && value.length > maxLength) {
      throw FormatException(
        'Expected "$path" length to be <= $maxLength, got ${value.length}.',
      );
    }
    return value;
  }
  throw FormatException('Expected "$path" to be a non-empty string.');
}

String? _readNullableString(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Expected "$path" to be a non-empty string or null.');
}

int _readInt(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$path" to be an integer.');
}

int _readNonNegativeInt(JsonMap map, String key, {String? parentPath}) {
  final value = _readInt(map, key, parentPath: parentPath);
  if (value < 0) {
    final path = parentPath == null ? key : '$parentPath.$key';
    throw FormatException('Expected "$path" to be >= 0.');
  }
  return value;
}

int _readRangeInt(
  JsonMap map,
  String key, {
  required int min,
  required int max,
  String? parentPath,
}) {
  final value = _readInt(map, key, parentPath: parentPath);
  if (value < min || value > max) {
    final path = parentPath == null ? key : '$parentPath.$key';
    throw FormatException('Expected "$path" to be between $min and $max.');
  }
  return value;
}

String _readEnum(
  JsonMap map,
  String key, {
  required Set<String> allowed,
  String? parentPath,
}) {
  final value = _readString(map, key, parentPath: parentPath);
  if (!allowed.contains(value)) {
    final path = parentPath == null ? key : '$parentPath.$key';
    throw FormatException(
      'Expected "$path" to be one of: ${allowed.toList()..sort()}.',
    );
  }
  return value;
}

List<String> _readStringList(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final values = _readList(map, key, parentPath: parentPath);

  final output = <String>[];
  for (var i = 0; i < values.length; i++) {
    final item = values[i];
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('Expected "$path[$i]" to be a non-empty string.');
    }
    output.add(item);
  }

  return output;
}

OptionMap _readOptionMap(
  JsonMap map,
  String key, {
  String? parentPath,
  required int maxValueLength,
}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final rawMap = _readMap(map, key, parentPath: parentPath);
  final optionMap = OptionMap.fromJson(rawMap, path: path);

  for (final optionKey in optionKeys) {
    final optionText = optionMap.byKey(optionKey);
    if (optionText.length > maxValueLength) {
      throw FormatException(
        'Expected "$path.$optionKey" length to be <= $maxValueLength, '
        'got ${optionText.length}.',
      );
    }
  }

  return optionMap;
}

Object? _readOptionalJsonValue(JsonMap map, String key, {String? parentPath}) {
  if (!map.containsKey(key)) {
    return null;
  }

  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value == null) {
    return null;
  }

  if (_isValidJsonValue(value)) {
    return value;
  }

  throw FormatException('Expected "$path" to be a JSON-compatible value.');
}

bool _isValidJsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return true;
  }

  if (value is List<Object?>) {
    return value.every(_isValidJsonValue);
  }

  if (value is JsonMap) {
    for (final entry in value.entries) {
      if (!_isValidJsonValue(entry.value)) {
        return false;
      }
    }
    return true;
  }

  return false;
}

int _capAtDb(int requested, int dbMax) {
  if (requested <= dbMax) {
    return requested;
  }
  return dbMax;
}
