import 'dart:convert';

typedef JsonMap = Map<String, Object?>;

const List<String> optionKeys = <String>['A', 'B', 'C', 'D', 'E'];
const Set<String> turnSpeakers = <String>{'S1', 'S2', 'N'};

class Sentence {
  const Sentence({required this.id, required this.text});

  final String id;
  final String text;

  factory Sentence.fromJson(JsonMap json, {required String path}) {
    return Sentence(
      id: readRequiredString(json, 'id', path: '$path.id'),
      text: readRequiredString(json, 'text', path: '$path.text'),
    );
  }

  JsonMap toJson() {
    return <String, Object?>{'id': id, 'text': text};
  }
}

class Turn {
  const Turn({required this.speaker, required this.sentenceIds});

  final String speaker;
  final List<String> sentenceIds;

  factory Turn.fromJson(JsonMap json, {required String path}) {
    final speaker = readRequiredString(json, 'speaker', path: '$path.speaker');
    if (!turnSpeakers.contains(speaker)) {
      throw FormatException(
        'Expected "$path.speaker" to be one of ${turnSpeakers.toList()..sort()}.',
      );
    }

    final sentenceIds = readStringList(
      json,
      'sentenceIds',
      path: '$path.sentenceIds',
    );
    if (sentenceIds.isEmpty) {
      throw FormatException('Expected "$path.sentenceIds" to be non-empty.');
    }

    return Turn(speaker: speaker, sentenceIds: sentenceIds);
  }

  JsonMap toJson() {
    return <String, Object?>{'speaker': speaker, 'sentenceIds': sentenceIds};
  }
}

class NumericRange {
  const NumericRange({required this.min, required this.max});

  final double min;
  final double max;

  factory NumericRange.fromJson(JsonMap json, {required String path}) {
    final minRaw = json['min'];
    final maxRaw = json['max'];
    if (minRaw is! num || maxRaw is! num) {
      throw FormatException(
        'Expected "$path.min" and "$path.max" to be numbers.',
      );
    }

    final min = minRaw.toDouble();
    final max = maxRaw.toDouble();
    if (min > max) {
      throw FormatException('Expected "$path.min" to be <= "$path.max".');
    }

    return NumericRange(min: min, max: max);
  }

  JsonMap toJson() {
    return <String, Object?>{'min': min, 'max': max};
  }
}

class TtsPlan {
  const TtsPlan({
    required this.repeatPolicy,
    required this.pauseRangeMs,
    required this.rateRange,
    required this.pitchRange,
    required this.voiceRoles,
  });

  final JsonMap repeatPolicy;
  final NumericRange pauseRangeMs;
  final NumericRange rateRange;
  final NumericRange pitchRange;
  final Map<String, String> voiceRoles;

  factory TtsPlan.fromJson(JsonMap json, {required String path}) {
    final repeatPolicy = readRequiredMap(
      json,
      'repeatPolicy',
      path: '$path.repeatPolicy',
    );
    if (repeatPolicy.isEmpty) {
      throw FormatException('Expected "$path.repeatPolicy" to be non-empty.');
    }

    final pauseRangeMs = NumericRange.fromJson(
      readRequiredMap(json, 'pauseRangeMs', path: '$path.pauseRangeMs'),
      path: '$path.pauseRangeMs',
    );
    final rateRange = NumericRange.fromJson(
      readRequiredMap(json, 'rateRange', path: '$path.rateRange'),
      path: '$path.rateRange',
    );
    final pitchRange = NumericRange.fromJson(
      readRequiredMap(json, 'pitchRange', path: '$path.pitchRange'),
      path: '$path.pitchRange',
    );

    final voiceRolesRaw = readRequiredMap(
      json,
      'voiceRoles',
      path: '$path.voiceRoles',
    );
    final voiceRoles = <String, String>{};
    for (final role in turnSpeakers) {
      final voice = voiceRolesRaw[role];
      if (voice is! String || voice.trim().isEmpty) {
        throw FormatException(
          'Expected "$path.voiceRoles.$role" to be a non-empty string.',
        );
      }
      voiceRoles[role] = voice;
    }

    return TtsPlan(
      repeatPolicy: repeatPolicy,
      pauseRangeMs: pauseRangeMs,
      rateRange: rateRange,
      pitchRange: pitchRange,
      voiceRoles: voiceRoles,
    );
  }

  JsonMap toJson() {
    return <String, Object?>{
      'repeatPolicy': repeatPolicy,
      'pauseRangeMs': pauseRangeMs.toJson(),
      'rateRange': rateRange.toJson(),
      'pitchRange': pitchRange.toJson(),
      'voiceRoles': voiceRoles,
    };
  }
}

class OptionMap {
  const OptionMap({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
  });

  final String a;
  final String b;
  final String c;
  final String d;
  final String e;

  factory OptionMap.fromJson(JsonMap json, {required String path}) {
    final keySet = json.keys.toSet();
    if (json.length != optionKeys.length || !keySet.containsAll(optionKeys)) {
      throw FormatException(
        'Expected "$path" to contain exactly keys A, B, C, D, and E.',
      );
    }

    return OptionMap(
      a: readRequiredString(json, 'A', path: '$path.A'),
      b: readRequiredString(json, 'B', path: '$path.B'),
      c: readRequiredString(json, 'C', path: '$path.C'),
      d: readRequiredString(json, 'D', path: '$path.D'),
      e: readRequiredString(json, 'E', path: '$path.E'),
    );
  }

  JsonMap toJson() {
    return <String, Object?>{'A': a, 'B': b, 'C': c, 'D': d, 'E': e};
  }

  List<String> valuesInOrder() => <String>[a, b, c, d, e];

  String byKey(String key) {
    switch (key) {
      case 'A':
        return a;
      case 'B':
        return b;
      case 'C':
        return c;
      case 'D':
        return d;
      case 'E':
        return e;
      default:
        throw ArgumentError.value(key, 'key', 'Expected one of A..E');
    }
  }
}

String readRequiredString(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('Expected "$path" to be a non-empty string.');
}

JsonMap readRequiredMap(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Expected "$path" to be a JSON object.');
}

List<String> readStringList(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('Expected "$path" to be a JSON array.');
  }

  final output = <String>[];
  for (var i = 0; i < value.length; i++) {
    final item = value[i];
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('Expected "$path[$i]" to be a non-empty string.');
    }
    output.add(item);
  }
  return output;
}

Object decodeJsonString(String value, {required String path}) {
  try {
    return jsonDecode(value);
  } on FormatException catch (error) {
    throw FormatException('Invalid JSON in "$path": ${error.message}');
  }
}
