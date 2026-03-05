import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resol_routine/core/domain/content_type_tag_taxonomy.dart';

void main() {
  test(
    'frontend taxonomy constants stay in sync with backend contract file',
    () {
      final contractFile = File(
        'backend/shared/contracts/content_type_tags.json',
      );
      expect(contractFile.existsSync(), isTrue);

      final decoded = jsonDecode(contractFile.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final root = decoded as Map<String, dynamic>;

      final entries = root['entries'];
      expect(entries, isA<List<dynamic>>());

      final listening = <String>{};
      final reading = <String>{};
      final aliases = <String, String>{};

      for (final rawEntry in entries as List<dynamic>) {
        final entry = rawEntry as Map<String, dynamic>;
        final skill = entry['skill'] as String;
        final canonicalTypeTag = entry['canonicalTypeTag'] as String;
        final legacyAliases = (entry['legacyAliases'] as List<dynamic>)
            .cast<String>();

        if (skill == 'LISTENING') {
          listening.add(canonicalTypeTag);
        } else if (skill == 'READING') {
          reading.add(canonicalTypeTag);
        } else {
          fail('Unexpected skill in contract: $skill');
        }

        for (final alias in legacyAliases) {
          aliases[alias] = canonicalTypeTag;
        }
      }

      expect(listening, canonicalListeningTypeTags);
      expect(reading, canonicalReadingTypeTags);
      expect(aliases, legacyTypeTagToCanonical);
    },
  );
}
