import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/time/day_key.dart';

void main() {
  group('day_key', () {
    test('formatDayKey returns yyyyMMdd', () {
      final formatted = formatDayKey(DateTime(2026, 1, 5, 14, 30));

      expect(formatted, '20260105');
    });

    test('validateDayKey accepts valid day key', () {
      expect(() => validateDayKey('20260105'), returnsNormally);
      expect(() => validateDayKey('20240229'), returnsNormally);
    });

    test('validateDayKey rejects invalid length', () {
      expect(() => validateDayKey('2026015'), throwsA(isA<FormatException>()));
      expect(
        () => validateDayKey('202601050'),
        throwsA(isA<FormatException>()),
      );
    });

    test('validateDayKey rejects non-digit characters', () {
      expect(() => validateDayKey('2026A105'), throwsA(isA<FormatException>()));
    });

    test('validateDayKey rejects invalid calendar date', () {
      expect(() => validateDayKey('20250230'), throwsA(isA<FormatException>()));
      expect(() => validateDayKey('20261301'), throwsA(isA<FormatException>()));
      expect(() => validateDayKey('20260200'), throwsA(isA<FormatException>()));
    });
  });
}
