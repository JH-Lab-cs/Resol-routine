import 'package:flutter_test/flutter_test.dart';
import 'package:resol_routine/core/domain/content_type_tag_taxonomy.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';

void main() {
  group('content type tag taxonomy', () {
    test('accepts canonical tags as-is', () {
      expect(
        normalizeTypeTagForStorage(
          skill: Skill.listening,
          rawTypeTag: 'L_GIST',
        ),
        'L_GIST',
      );
      expect(
        normalizeTypeTagForStorage(
          skill: Skill.reading,
          rawTypeTag: 'R_MAIN_IDEA',
        ),
        'R_MAIN_IDEA',
      );
    });

    test('normalizes legacy numeric tags to canonical tags', () {
      expect(
        normalizeTypeTagForStorage(skill: Skill.listening, rawTypeTag: 'L1'),
        'L_GIST',
      );
      expect(
        normalizeTypeTagForStorage(skill: Skill.reading, rawTypeTag: 'R2'),
        'R_DETAIL',
      );
    });

    test('rejects unsupported or mismatched tags', () {
      expect(
        () => normalizeTypeTagForStorage(
          skill: Skill.reading,
          rawTypeTag: 'L_GIST',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => normalizeTypeTagForStorage(
          skill: Skill.listening,
          rawTypeTag: 'L_UNKNOWN',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
