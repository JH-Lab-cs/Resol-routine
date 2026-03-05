import 'package:flutter/foundation.dart';

const Map<String, String> _skillLabels = <String, String>{
  'LISTENING': '듣기',
  'READING': '독해',
};

const Map<String, String> _trackLabels = <String, String>{
  'M3': '중3',
  'H1': '고1',
  'H2': '고2',
  'H3': '고3',
};

const Map<String, String> _wrongReasonLabels = <String, String>{
  'VOCAB': '어휘',
  'EVIDENCE': '근거',
  'INFERENCE': '추론',
  'CARELESS': '부주의',
  'TIME': '시간 부족',
};

String displaySkill(String skill) {
  return _displayFromMap(kind: 'skill', value: skill, labels: _skillLabels);
}

String displayTrack(String track) {
  return _displayFromMap(kind: 'track', value: track, labels: _trackLabels);
}

String displayWrongReasonTag(String tag) {
  return _displayFromMap(
    kind: 'wrongReasonTag',
    value: tag,
    labels: _wrongReasonLabels,
  );
}

String _displayFromMap({
  required String kind,
  required String value,
  required Map<String, String> labels,
}) {
  final mapped = labels[value];
  if (mapped != null) {
    return mapped;
  }

  assert(() {
    debugPrint('[label_maps] Unknown $kind value: $value');
    return true;
  }());
  return value;
}
