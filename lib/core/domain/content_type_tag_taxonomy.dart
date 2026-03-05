import 'domain_enums.dart';

const Set<String> canonicalListeningTypeTags = <String>{
  'L_GIST',
  'L_DETAIL',
  'L_INTENT',
  'L_RESPONSE',
  'L_SITUATION',
  'L_LONG_TALK',
};

const Set<String> canonicalReadingTypeTags = <String>{
  'R_MAIN_IDEA',
  'R_DETAIL',
  'R_INFERENCE',
  'R_BLANK',
  'R_ORDER',
  'R_INSERTION',
  'R_SUMMARY',
  'R_VOCAB',
};

const Map<String, String> legacyTypeTagToCanonical = <String, String>{
  'L1': 'L_GIST',
  'L2': 'L_DETAIL',
  'L3': 'L_INTENT',
  'R1': 'R_MAIN_IDEA',
  'R2': 'R_DETAIL',
  'R3': 'R_INFERENCE',
};

const Set<String> legacyListeningTypeTags = <String>{'L1', 'L2', 'L3'};
const Set<String> legacyReadingTypeTags = <String>{'R1', 'R2', 'R3'};

Set<String> canonicalTypeTagsForSkill(Skill skill) {
  return switch (skill) {
    Skill.listening => canonicalListeningTypeTags,
    Skill.reading => canonicalReadingTypeTags,
  };
}

Set<String> legacyTypeTagsForSkill(Skill skill) {
  return switch (skill) {
    Skill.listening => legacyListeningTypeTags,
    Skill.reading => legacyReadingTypeTags,
  };
}

bool isCanonicalTypeTagForSkill({
  required Skill skill,
  required String typeTag,
}) {
  return canonicalTypeTagsForSkill(
    skill,
  ).contains(typeTag.trim().toUpperCase());
}

bool isLegacyTypeTagForSkill({required Skill skill, required String typeTag}) {
  return legacyTypeTagsForSkill(skill).contains(typeTag.trim().toUpperCase());
}

String normalizeTypeTagForStorage({
  required Skill skill,
  required String rawTypeTag,
}) {
  final normalized = rawTypeTag.trim().toUpperCase();
  final canonical = legacyTypeTagToCanonical[normalized] ?? normalized;
  if (!canonicalTypeTagsForSkill(skill).contains(canonical)) {
    throw FormatException(
      'Unsupported typeTag "$rawTypeTag" for skill ${skill.dbValue}.',
    );
  }
  return canonical;
}
