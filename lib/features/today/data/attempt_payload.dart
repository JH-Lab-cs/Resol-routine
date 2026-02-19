import 'dart:convert';

import '../../../core/domain/domain_enums.dart';

const List<WrongReasonTag> wrongReasonTags = WrongReasonTag.values;

class AttemptPayload {
  const AttemptPayload({required this.selectedAnswer, this.wrongReasonTag});

  final String selectedAnswer;
  final WrongReasonTag? wrongReasonTag;

  String encode() {
    return jsonEncode(<String, Object?>{
      'selectedAnswer': selectedAnswer,
      'wrongReasonTag': wrongReasonTag?.dbValue,
    });
  }

  static AttemptPayload decode(String rawJson) {
    final decoded = jsonDecode(rawJson);

    if (decoded is String) {
      return AttemptPayload(selectedAnswer: decoded);
    }

    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Attempt payload must be JSON string or object.',
      );
    }

    final answer = decoded['selectedAnswer'];
    if (answer is! String || answer.isEmpty) {
      throw const FormatException(
        'selectedAnswer is required in attempt payload.',
      );
    }

    final wrongReasonRaw = decoded['wrongReasonTag'];
    if (wrongReasonRaw == null) {
      return AttemptPayload(selectedAnswer: answer);
    }
    if (wrongReasonRaw is! String || wrongReasonRaw.isEmpty) {
      throw const FormatException(
        'wrongReasonTag must be a non-empty string when present.',
      );
    }

    return AttemptPayload(
      selectedAnswer: answer,
      wrongReasonTag: wrongReasonTagFromDbOrNull(wrongReasonRaw),
    );
  }
}
