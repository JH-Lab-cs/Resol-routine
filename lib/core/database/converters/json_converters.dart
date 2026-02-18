import 'dart:convert';

import 'package:drift/drift.dart';

import 'json_models.dart';

class SentencesConverter extends TypeConverter<List<Sentence>, String> {
  const SentencesConverter();

  @override
  List<Sentence> fromSql(String fromDb) {
    final decoded = decodeJsonString(fromDb, path: 'sentencesJson');
    if (decoded is! List<Object?>) {
      throw const FormatException('sentencesJson must decode to a JSON array.');
    }

    final sentences = <Sentence>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! JsonMap) {
        throw FormatException('sentencesJson[$i] must be a JSON object.');
      }
      sentences.add(Sentence.fromJson(item, path: 'sentencesJson[$i]'));
    }
    return sentences;
  }

  @override
  String toSql(List<Sentence> value) {
    return jsonEncode(
      value.map((Sentence sentence) => sentence.toJson()).toList(),
    );
  }
}

class TurnsConverter extends TypeConverter<List<Turn>, String> {
  const TurnsConverter();

  @override
  List<Turn> fromSql(String fromDb) {
    final decoded = decodeJsonString(fromDb, path: 'turnsJson');
    if (decoded is! List<Object?>) {
      throw const FormatException('turnsJson must decode to a JSON array.');
    }

    final turns = <Turn>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! JsonMap) {
        throw FormatException('turnsJson[$i] must be a JSON object.');
      }
      turns.add(Turn.fromJson(item, path: 'turnsJson[$i]'));
    }
    return turns;
  }

  @override
  String toSql(List<Turn> value) {
    return jsonEncode(value.map((Turn turn) => turn.toJson()).toList());
  }
}

class TtsPlanConverter extends TypeConverter<TtsPlan, String> {
  const TtsPlanConverter();

  @override
  TtsPlan fromSql(String fromDb) {
    final decoded = decodeJsonString(fromDb, path: 'ttsPlanJson');
    if (decoded is! JsonMap) {
      throw const FormatException('ttsPlanJson must decode to a JSON object.');
    }

    return TtsPlan.fromJson(decoded, path: 'ttsPlanJson');
  }

  @override
  String toSql(TtsPlan value) {
    return jsonEncode(value.toJson());
  }
}

class OptionMapConverter extends TypeConverter<OptionMap, String> {
  const OptionMapConverter();

  @override
  OptionMap fromSql(String fromDb) {
    final decoded = decodeJsonString(fromDb, path: 'optionMapJson');
    if (decoded is! JsonMap) {
      throw const FormatException(
        'Option map column must decode to a JSON object.',
      );
    }

    return OptionMap.fromJson(decoded, path: 'optionMapJson');
  }

  @override
  String toSql(OptionMap value) {
    return jsonEncode(value.toJson());
  }
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = decodeJsonString(fromDb, path: 'stringListJson');
    if (decoded is! List<Object?>) {
      throw const FormatException(
        'String list column must decode to a JSON array.',
      );
    }

    final values = <String>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! String || item.trim().isEmpty) {
        throw FormatException('stringListJson[$i] must be a non-empty string.');
      }
      values.add(item);
    }
    return values;
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}
