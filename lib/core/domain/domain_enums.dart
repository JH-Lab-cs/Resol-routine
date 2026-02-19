enum Skill { listening, reading }

enum Track { m3, h1, h2, h3 }

enum WrongReasonTag { vocab, evidence, inference, careless, time }

extension SkillDbValue on Skill {
  String get dbValue {
    switch (this) {
      case Skill.listening:
        return 'LISTENING';
      case Skill.reading:
        return 'READING';
    }
  }
}

extension TrackDbValue on Track {
  String get dbValue {
    switch (this) {
      case Track.m3:
        return 'M3';
      case Track.h1:
        return 'H1';
      case Track.h2:
        return 'H2';
      case Track.h3:
        return 'H3';
    }
  }
}

extension WrongReasonTagDbValue on WrongReasonTag {
  String get dbValue {
    switch (this) {
      case WrongReasonTag.vocab:
        return 'VOCAB';
      case WrongReasonTag.evidence:
        return 'EVIDENCE';
      case WrongReasonTag.inference:
        return 'INFERENCE';
      case WrongReasonTag.careless:
        return 'CARELESS';
      case WrongReasonTag.time:
        return 'TIME';
    }
  }
}

Skill skillFromDb(String raw) {
  switch (raw) {
    case 'LISTENING':
      return Skill.listening;
    case 'READING':
      return Skill.reading;
    default:
      throw FormatException('Unsupported skill value: "$raw"');
  }
}

Track trackFromDb(String raw) {
  switch (raw) {
    case 'M3':
      return Track.m3;
    case 'H1':
      return Track.h1;
    case 'H2':
      return Track.h2;
    case 'H3':
      return Track.h3;
    default:
      throw FormatException('Unsupported track value: "$raw"');
  }
}

WrongReasonTag wrongReasonTagFromDb(String raw) {
  switch (raw) {
    case 'VOCAB':
      return WrongReasonTag.vocab;
    case 'EVIDENCE':
      return WrongReasonTag.evidence;
    case 'INFERENCE':
      return WrongReasonTag.inference;
    case 'CARELESS':
      return WrongReasonTag.careless;
    case 'TIME':
      return WrongReasonTag.time;
    default:
      throw FormatException('Unsupported wrong reason tag value: "$raw"');
  }
}

WrongReasonTag? wrongReasonTagFromDbOrNull(String? raw) {
  if (raw == null) {
    return null;
  }
  try {
    return wrongReasonTagFromDb(raw);
  } on FormatException {
    return null;
  }
}
