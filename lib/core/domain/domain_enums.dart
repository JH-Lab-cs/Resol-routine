enum Skill { listening, reading }

enum Track { m3, h1, h2, h3 }

enum MockExamType { weekly, monthly }

enum WrongReasonTag { vocab, evidence, inference, careless, time }

enum VocabSourceTag { csat, schoolCore, userCustom }

enum DailySectionOrder { listeningFirst, readingFirst }

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

extension MockExamTypeDbValue on MockExamType {
  String get dbValue {
    switch (this) {
      case MockExamType.weekly:
        return 'WEEKLY';
      case MockExamType.monthly:
        return 'MONTHLY';
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

extension VocabSourceTagDbValue on VocabSourceTag {
  String get dbValue {
    switch (this) {
      case VocabSourceTag.csat:
        return 'CSAT';
      case VocabSourceTag.schoolCore:
        return 'SCHOOL_CORE';
      case VocabSourceTag.userCustom:
        return 'USER_CUSTOM';
    }
  }
}

extension DailySectionOrderJsonValue on DailySectionOrder {
  String get jsonValue {
    switch (this) {
      case DailySectionOrder.listeningFirst:
        return 'listening-first';
      case DailySectionOrder.readingFirst:
        return 'reading-first';
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

MockExamType mockExamTypeFromDb(String raw) {
  switch (raw) {
    case 'WEEKLY':
      return MockExamType.weekly;
    case 'MONTHLY':
      return MockExamType.monthly;
    default:
      throw FormatException('Unsupported mock exam type value: "$raw"');
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

VocabSourceTag vocabSourceTagFromDb(String raw) {
  switch (raw) {
    case 'CSAT':
      return VocabSourceTag.csat;
    case 'SCHOOL_CORE':
      return VocabSourceTag.schoolCore;
    case 'USER_CUSTOM':
      return VocabSourceTag.userCustom;
    default:
      throw FormatException('Unsupported vocab source tag value: "$raw"');
  }
}

VocabSourceTag? vocabSourceTagFromDbOrNull(String? raw) {
  if (raw == null) {
    return null;
  }
  try {
    return vocabSourceTagFromDb(raw);
  } on FormatException {
    return null;
  }
}

DailySectionOrder dailySectionOrderFromJson(String raw) {
  switch (raw) {
    case 'listening-first':
      return DailySectionOrder.listeningFirst;
    case 'reading-first':
      return DailySectionOrder.readingFirst;
    default:
      throw FormatException('Unsupported daily section order value: "$raw"');
  }
}

DailySectionOrder? dailySectionOrderFromJsonOrNull(String? raw) {
  if (raw == null) {
    return null;
  }
  try {
    return dailySectionOrderFromJson(raw);
  } on FormatException {
    return null;
  }
}
