import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Formats an 8-digit birth date string as `YYYY-MM-DD`.
/// Input digits are constrained to numbers only and separators are injected.
class BirthDateTextInputFormatter extends TextInputFormatter {
  const BirthDateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final rawDigits = _digitsOnly(newValue.text);
    final digits = rawDigits.length > 8 ? rawDigits.substring(0, 8) : rawDigits;
    final formatted = _formatBirthDateDigits(digits);

    final boundedOffset = math.min(
      newValue.selection.extentOffset,
      newValue.text.length,
    );
    final digitsBeforeCursor = _digitsOnly(
      newValue.text.substring(0, boundedOffset),
    ).length;
    final clampedDigitsBeforeCursor = math.min(
      digitsBeforeCursor,
      digits.length,
    );
    final nextCursorOffset = _offsetForDigitCount(
      formatted,
      clampedDigitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: nextCursorOffset),
      composing: TextRange.empty,
    );
  }

  static String _digitsOnly(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _formatBirthDateDigits(String digits) {
    if (digits.isEmpty) {
      return '';
    }
    if (digits.length <= 4) {
      return digits;
    }
    if (digits.length <= 6) {
      return '${digits.substring(0, 4)}-${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6)}';
  }

  static int _offsetForDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) {
      return 0;
    }

    var seenDigits = 0;
    for (var i = 0; i < formatted.length; i++) {
      final codeUnit = formatted.codeUnitAt(i);
      if (codeUnit >= 48 && codeUnit <= 57) {
        seenDigits += 1;
        if (seenDigits == digitCount) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }
}

bool isValidBirthDateText(String input) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) {
    return false;
  }
  try {
    final parsed = DateTime.parse(input);
    final normalized =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    return normalized == input;
  } catch (_) {
    return false;
  }
}
