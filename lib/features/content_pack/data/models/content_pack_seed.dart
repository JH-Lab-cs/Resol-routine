import 'dart:convert';

typedef JsonMap = Map<String, Object?>;

class SeedContentPack {
  const SeedContentPack({
    required this.id,
    required this.version,
    required this.locale,
    required this.title,
    required this.description,
    required this.checksum,
    required this.passages,
    required this.vocabulary,
  });

  final String id;
  final int version;
  final String locale;
  final String title;
  final String? description;
  final String checksum;
  final List<SeedPassage> passages;
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

    final passagesJson = _readList(json, 'passages');
    final passages = <SeedPassage>[];
    for (var i = 0; i < passagesJson.length; i++) {
      passages.add(
        SeedPassage.fromJson(
          _readMapFromDynamic(passagesJson[i], 'passages[$i]'),
        ),
      );
    }

    final vocabularyJson = _readList(json, 'vocabulary');
    final vocabulary = <SeedVocabItem>[];
    for (var i = 0; i < vocabularyJson.length; i++) {
      vocabulary.add(
        SeedVocabItem.fromJson(
          _readMapFromDynamic(vocabularyJson[i], 'vocabulary[$i]'),
        ),
      );
    }

    return SeedContentPack(
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
      passages: passages,
      vocabulary: vocabulary,
    );
  }
}

class SeedPassage {
  const SeedPassage({
    required this.id,
    required this.title,
    required this.body,
    required this.order,
    required this.difficulty,
    required this.scripts,
    required this.questions,
  });

  final String id;
  final String title;
  final String body;
  final int order;
  final int difficulty;
  final List<SeedScriptLine> scripts;
  final List<SeedQuestion> questions;

  factory SeedPassage.fromJson(JsonMap json) {
    final scriptsJson = _readList(json, 'scripts');
    final scripts = <SeedScriptLine>[];
    for (var i = 0; i < scriptsJson.length; i++) {
      scripts.add(
        SeedScriptLine.fromJson(
          _readMapFromDynamic(scriptsJson[i], 'scripts[$i]'),
        ),
      );
    }

    final questionsJson = _readList(json, 'questions');
    final questions = <SeedQuestion>[];
    for (var i = 0; i < questionsJson.length; i++) {
      questions.add(
        SeedQuestion.fromJson(
          _readMapFromDynamic(questionsJson[i], 'questions[$i]'),
        ),
      );
    }

    return SeedPassage(
      id: _readString(json, 'id'),
      title: _readString(json, 'title'),
      body: _readString(json, 'body'),
      order: _readInt(json, 'order'),
      difficulty: _readInt(json, 'difficulty'),
      scripts: scripts,
      questions: questions,
    );
  }
}

class SeedScriptLine {
  const SeedScriptLine({
    required this.id,
    required this.speaker,
    required this.text,
    required this.order,
  });

  final String id;
  final String speaker;
  final String text;
  final int order;

  factory SeedScriptLine.fromJson(JsonMap json) {
    return SeedScriptLine(
      id: _readString(json, 'id'),
      speaker: _readString(json, 'speaker'),
      text: _readString(json, 'text'),
      order: _readInt(json, 'order'),
    );
  }
}

class SeedQuestion {
  const SeedQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    required this.options,
    required this.answer,
    required this.order,
    required this.explanations,
  });

  final String id;
  final String prompt;
  final String type;
  final List<String>? options;
  final Object? answer;
  final int order;
  final List<SeedExplanation> explanations;

  factory SeedQuestion.fromJson(JsonMap json) {
    final explanationsJson = _readList(json, 'explanations');
    final explanations = <SeedExplanation>[];
    for (var i = 0; i < explanationsJson.length; i++) {
      explanations.add(
        SeedExplanation.fromJson(
          _readMapFromDynamic(explanationsJson[i], 'explanations[$i]'),
        ),
      );
    }

    return SeedQuestion(
      id: _readString(json, 'id'),
      prompt: _readString(json, 'prompt'),
      type: _readString(json, 'type'),
      options: _readNullableStringList(json, 'options'),
      answer: _readJsonValue(json, 'answer'),
      order: _readInt(json, 'order'),
      explanations: explanations,
    );
  }
}

class SeedExplanation {
  const SeedExplanation({required this.id, required this.body});

  final String id;
  final String body;

  factory SeedExplanation.fromJson(JsonMap json) {
    return SeedExplanation(
      id: _readString(json, 'id'),
      body: _readString(json, 'body'),
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

  factory SeedVocabItem.fromJson(JsonMap json) {
    return SeedVocabItem(
      id: _readString(json, 'id'),
      lemma: _readString(json, 'lemma'),
      partOfSpeech: _readNullableString(json, 'pos'),
      meaning: _readString(json, 'meaning'),
      example: _readNullableString(json, 'example'),
      ipa: _readNullableString(json, 'ipa'),
    );
  }
}

JsonMap _readMap(JsonMap map, String key) {
  final value = map[key];
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Expected "$key" to be a JSON object.');
}

JsonMap _readMapFromDynamic(Object? value, String path) {
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Expected "$path" to be a JSON object.');
}

List<Object?> _readList(JsonMap map, String key) {
  final value = map[key];
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('Expected "$key" to be a JSON array.');
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
  throw FormatException('Expected "$path" to be a string or null.');
}

int _readInt(JsonMap map, String key, {String? parentPath}) {
  final path = parentPath == null ? key : '$parentPath.$key';
  final value = map[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$path" to be an integer.');
}

List<String>? _readNullableStringList(JsonMap map, String key) {
  if (!map.containsKey(key) || map[key] == null) {
    return null;
  }

  final value = map[key];
  if (value is! List<Object?>) {
    throw FormatException('Expected "$key" to be a list of strings.');
  }

  final output = <String>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('Expected "$key[$i]" to be a non-empty string.');
    }
    output.add(item);
  }

  return output;
}

Object? _readJsonValue(JsonMap map, String key) {
  if (!map.containsKey(key)) {
    throw FormatException('Missing required field "$key".');
  }

  final value = map[key];
  if (_isValidJsonValue(value)) {
    return value;
  }

  throw FormatException('Expected "$key" to contain a JSON-compatible value.');
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
