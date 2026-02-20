import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/ui/input_formatters/birth_date_input_formatter.dart';

void main() {
  group('BirthDateTextInputFormatter', () {
    const formatter = BirthDateTextInputFormatter();

    test('formats digit input as YYYY-MM-DD', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '20030201',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '2003-02-01');
      expect(result.selection.baseOffset, 10);
    });

    test('removes trailing separator naturally when deleting a digit', () {
      const oldValue = TextEditingValue(
        text: '2003-02',
        selection: TextSelection.collapsed(offset: 7),
      );
      const newValue = TextEditingValue(
        text: '2003-0',
        selection: TextSelection.collapsed(offset: 6),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '2003-0');
      expect(result.selection.baseOffset, 6);
    });

    test('drops second separator when day section is deleted', () {
      const oldValue = TextEditingValue(
        text: '2003-02-1',
        selection: TextSelection.collapsed(offset: 9),
      );
      const newValue = TextEditingValue(
        text: '2003-02-',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '2003-02');
      expect(result.selection.baseOffset, 7);
    });
  });

  group('isValidBirthDateText', () {
    test('accepts a valid date', () {
      expect(isValidBirthDateText('2003-02-01'), isTrue);
    });

    test('rejects invalid date format and invalid calendar dates', () {
      expect(isValidBirthDateText('2003-2-1'), isFalse);
      expect(isValidBirthDateText('2003-02-31'), isFalse);
      expect(isValidBirthDateText('abcd-ef-gh'), isFalse);
    });
  });
}
