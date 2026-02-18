import 'dart:convert';

typedef JsonMap = Map<String, Object?>;

const Set<String> _optionKeys = {'A', 'B', 'C', 'D', 'E'};
const Set<String> _allowedSkills = {'LISTENING', 'READING', 'VOCAB'};
const Set<String> _allowedTracks = {'M3', 'H1', 'H2', 'H3'};
const Set<String> _allowedTurnSpeakers = {'S1', 'S2', 'N'};

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

  static SeedContentPack parse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! JsonMap) {
      throw const FormatException(
        'The content pack root must be a JSON object.',
      );
    }

    return SeedContentPack.fromJson(decoded);
  }

  factory SeedContentPack.fromJson(JsonMap json) {
    final packJson = _readMap(json, 'pack');

    final scriptsJson = _readList(json, 'scripts');
    final scripts = <SeedScript>[];
    for (var i = 0; i < scriptsJson.length; i++) {
      scripts.add(
        SeedScript.fromJson(
          _readMapFromDynamic(scriptsJson[i], 'scripts[$i]'),
          path: 'scripts[$i]',
        ),
      );
    }

    final passagesJson = _readList(json, 'passages');
    final passages = <SeedPassage>[];
    for (var i = 0; i < passagesJson.length; i++) {
      passages.add(
        SeedPassage.fromJson(
          _readMapFromDynamic(passagesJson[i], 'passages[$i]'),
          path: 'passages[$i]',
        ),
      );
    }

    final questionsJson = _readList(json, 'questions');
    final questions = <SeedQuestion>[];
    for (var i = 0; i < questionsJson.length; i++) {
      questions.add(
        SeedQuestion.fromJson(
          _readMapFromDynamic(questionsJson[i], 'questions[$i]'),
          path: 'questions[$i]',
        ),
      );
    }

    final vocabularyJson = _readList(json, 'vocabulary');
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
      id: _readString(packJson, 'id', parentPath: 'pack'),
      version: _readInt(packJson, 'version', parentPath: 'pack'),
      locale: _readString(packJson, 'locale', parentPath: 'pack'),
      title: _readString(packJson, 'title', parentPath: 'pack'),
      description: _readNullableString(
        packJson,
        'description',
        parentPath: 'pack',
      ),
      checksum: _readString(packJson, 'checksum', parentPath: 'pack'),
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

      if (question.skill == 'LISTENING') {
        if (!hasScript || hasPassage) {
          throw FormatException(
            'LISTENING question "${question.id}" must set scriptId only.',
          );
        }
      } else if (question.skill == 'READING') {
        if (!hasPassage || hasScript) {
          throw FormatException(
            'READING question "${question.id}" must set passageId only.',
          );
        }
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
  final List<SeedSentence> sentences;
  final List<SeedTurn> turns;
  final SeedTtsPlan ttsPlan;

  Set<String> get sentenceIdSet =>
      sentences.map((SeedSentence sentence) => sentence.id).toSet();

  factory SeedScript.fromJson(JsonMap json, {required String path}) {
    final sentencesJson = _readList(json, 'sentences', parentPath: path);
    if (sentencesJson.isEmpty) {
      throw FormatException(
        '"$path.sentences" must contain at least one item.',
      );
    }

    final sentences = <SeedSentence>[];
    for (var i = 0; i < sentencesJson.length; i++) {
      sentences.add(
        SeedSentence.fromJson(
          _readMapFromDynamic(sentencesJson[i], '$path.sentences[$i]'),
          path: '$path.sentences[$i]',
        ),
      );
    }
    _ensureUniqueIds(
      sentences.map((SeedSentence sentence) => sentence.id),
      '$path.sentences',
    );

    final sentenceIdSet = sentences
        .map((SeedSentence sentence) => sentence.id)
        .toSet();

    final turnsJson = _readList(json, 'turns', parentPath: path);
    if (turnsJson.isEmpty) {
      throw FormatException('"$path.turns" must contain at least one item.');
    }

    final turns = <SeedTurn>[];
    for (var i = 0; i < turnsJson.length; i++) {
      final turn = SeedTurn.fromJson(
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

    return SeedScript(
      id: _readString(json, 'id', parentPath: path),
      order: _readNonNegativeInt(json, 'order', parentPath: path),
      sentences: sentences,
      turns: turns,
      ttsPlan: SeedTtsPlan.fromJson(
        _readMap(json, 'ttsPlan', parentPath: path),
        path: '$path.ttsPlan',
      ),
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
  final List<SeedSentence> sentences;

  Set<String> get sentenceIdSet =>
      sentences.map((SeedSentence sentence) => sentence.id).toSet();

  factory SeedPassage.fromJson(JsonMap json, {required String path}) {
    final sentencesJson = _readList(json, 'sentences', parentPath: path);
    if (sentencesJson.isEmpty) {
      throw FormatException(
        '"$path.sentences" must contain at least one item.',
      );
    }

    final sentences = <SeedSentence>[];
    for (var i = 0; i < sentencesJson.length; i++) {
      sentences.add(
        SeedSentence.fromJson(
          _readMapFromDynamic(sentencesJson[i], '$path.sentences[$i]'),
          path: '$path.sentences[$i]',
        ),
      );
    }
    _ensureUniqueIds(
      sentences.map((SeedSentence sentence) => sentence.id),
      '$path.sentences',
    );

    return SeedPassage(
      id: _readString(json, 'id', parentPath: path),
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
  final Map<String, String> options;
  final String answerKey;
  final int order;
  final SeedExplanation explanation;

  factory SeedQuestion.fromJson(JsonMap json, {required String path}) {
    final skill = _readEnum(
      json,
      'skill',
      allowed: _allowedSkills,
      parentPath: path,
    );

    final typeTag = _readString(json, 'typeTag', parentPath: path);
    if (skill == 'LISTENING' && !RegExp(r'^L\d+$').hasMatch(typeTag)) {
      throw FormatException('"$path.typeTag" must match L<digit...>.');
    }
    if (skill == 'READING' && !RegExp(r'^R\d+$').hasMatch(typeTag)) {
      throw FormatException('"$path.typeTag" must match R<digit...>.');
    }
    if (skill == 'VOCAB' && !RegExp(r'^V\d+$').hasMatch(typeTag)) {
      throw FormatException('"$path.typeTag" must match V<digit...>.');
    }

    final optionsMap = _readOptionMap(json, 'options', parentPath: path);
    final answerKey = _readEnum(
      json,
      'answerKey',
      allowed: _optionKeys,
      parentPath: path,
    );

    return SeedQuestion(
      id: _readString(json, 'id', parentPath: path),
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
      prompt: _readString(json, 'prompt', parentPath: path),
      options: optionsMap,
      answerKey: answerKey,
      order: _readNonNegativeInt(json, 'order', parentPath: path),
      explanation: SeedExplanation.fromJson(
        _readMap(json, 'explanation', parentPath: path),
        path: '$path.explanation',
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
  final Map<String, String> whyWrongKo;
  final Object? vocabNotes;
  final String? structureNotesKo;
  final Object? glossKo;

  factory SeedExplanation.fromJson(JsonMap json, {required String path}) {
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

    final whyWrongMap = _readOptionMap(json, 'whyWrongKo', parentPath: path);

    return SeedExplanation(
      id: _readString(json, 'id', parentPath: path),
      evidenceSentenceIds: evidenceSentenceIds,
      whyCorrectKo: _readString(json, 'whyCorrectKo', parentPath: path),
      whyWrongKo: whyWrongMap,
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

class SeedSentence {
  const SeedSentence({required this.id, required this.text});

  final String id;
  final String text;

  factory SeedSentence.fromJson(JsonMap json, {required String path}) {
    return SeedSentence(
      id: _readString(json, 'id', parentPath: path),
      text: _readString(json, 'text', parentPath: path),
    );
  }
}

class SeedTurn {
  const SeedTurn({required this.speaker, required this.sentenceIds});

  final String speaker;
  final List<String> sentenceIds;

  factory SeedTurn.fromJson(JsonMap json, {required String path}) {
    final sentenceIds = _readStringList(json, 'sentenceIds', parentPath: path);
    if (sentenceIds.isEmpty) {
      throw FormatException('"$path.sentenceIds" must not be empty.');
    }

    return SeedTurn(
      speaker: _readEnum(
        json,
        'speaker',
        allowed: _allowedTurnSpeakers,
        parentPath: path,
      ),
      sentenceIds: sentenceIds,
    );
  }
}

class SeedTtsPlan {
  const SeedTtsPlan({
    required this.repeatPolicy,
    required this.pauseRangeMs,
    required this.rateRange,
    required this.pitchRange,
    required this.voiceRoles,
  });

  final JsonMap repeatPolicy;
  final JsonMap pauseRangeMs;
  final JsonMap rateRange;
  final JsonMap pitchRange;
  final JsonMap voiceRoles;

  factory SeedTtsPlan.fromJson(JsonMap json, {required String path}) {
    final repeatPolicy = _readMap(json, 'repeatPolicy', parentPath: path);
    if (repeatPolicy.isEmpty) {
      throw FormatException('"$path.repeatPolicy" must not be empty.');
    }

    final pauseRangeMs = _readNumericRange(
      json,
      'pauseRangeMs',
      parentPath: path,
      requireNonNegative: true,
    );
    final rateRange = _readNumericRange(
      json,
      'rateRange',
      parentPath: path,
      minExclusiveZero: true,
    );
    final pitchRange = _readNumericRange(json, 'pitchRange', parentPath: path);

    final voiceRoles = _readMap(json, 'voiceRoles', parentPath: path);
    for (final role in _allowedTurnSpeakers) {
      final voice = voiceRoles[role];
      if (voice is! String || voice.trim().isEmpty) {
        throw FormatException(
          '"$path.voiceRoles.$role" must be a non-empty string.',
        );
      }
    }

    return SeedTtsPlan(
      repeatPolicy: repeatPolicy,
      pauseRangeMs: pauseRangeMs,
      rateRange: rateRange,
      pitchRange: pitchRange,
      voiceRoles: voiceRoles,
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
      id: _readString(json, 'id', parentPath: path),
      lemma: _readString(json, 'lemma', parentPath: path),
      partOfSpeech: _readNullableString(json, 'pos', parentPath: path),
      meaning: _readString(json, 'meaning', parentPath: path),
      example: _readNullableString(json, 'example', parentPath: path),
      ipa: _readNullableString(json, 'ipa', parentPath: path),
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

String _readString(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
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

Map<String, String> _readOptionMap(
  JsonMap map,
  String key, {
  String? parentPath,
}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final rawMap = _readMap(map, key, parentPath: parentPath);

  if (rawMap.length != _optionKeys.length ||
      !rawMap.keys.toSet().containsAll(_optionKeys)) {
    throw FormatException(
      'Expected "$path" to contain exactly keys A, B, C, D, and E.',
    );
  }

  final parsed = <String, String>{};
  for (final optionKey in _optionKeys) {
    final rawValue = rawMap[optionKey];
    if (rawValue is! String || rawValue.trim().isEmpty) {
      throw FormatException(
        'Expected "$path.$optionKey" to be a non-empty string.',
      );
    }
    parsed[optionKey] = rawValue;
  }

  return parsed;
}

JsonMap _readNumericRange(
  JsonMap map,
  String key, {
  String? parentPath,
  bool requireNonNegative = false,
  bool minExclusiveZero = false,
}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final raw = _readMap(map, key, parentPath: parentPath);

  final minValue = raw['min'];
  final maxValue = raw['max'];
  if (minValue is! num || maxValue is! num) {
    throw FormatException(
      'Expected "$path.min" and "$path.max" to be numbers.',
    );
  }

  final minDouble = minValue.toDouble();
  final maxDouble = maxValue.toDouble();

  if (minDouble > maxDouble) {
    throw FormatException('Expected "$path.min" to be <= "$path.max".');
  }

  if (requireNonNegative && (minDouble < 0 || maxDouble < 0)) {
    throw FormatException('Expected "$path" values to be non-negative.');
  }

  if (minExclusiveZero && (minDouble <= 0 || maxDouble <= 0)) {
    throw FormatException('Expected "$path" values to be > 0.');
  }

  return {'min': minValue, 'max': maxValue};
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
