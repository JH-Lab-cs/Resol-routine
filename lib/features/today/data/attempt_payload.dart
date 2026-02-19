import 'dart:convert';

const Set<String> wrongReasonTags = <String>{
  'VOCAB',
  'EVIDENCE',
  'INFERENCE',
  'CARELESS',
  'TIME',
};

class AttemptPayload {
  const AttemptPayload({required this.selectedAnswer, this.wrongReasonTag});

  final String selectedAnswer;
  final String? wrongReasonTag;

  String encode() {
    return jsonEncode(<String, Object?>{
      'selectedAnswer': selectedAnswer,
      'wrongReasonTag': wrongReasonTag,
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

    final wrongReason = decoded['wrongReasonTag'];
    if (wrongReason == null) {
      return AttemptPayload(selectedAnswer: answer);
    }
    if (wrongReason is! String || wrongReason.isEmpty) {
      throw const FormatException(
        'wrongReasonTag must be a non-empty string when present.',
      );
    }

    return AttemptPayload(selectedAnswer: answer, wrongReasonTag: wrongReason);
  }
}
