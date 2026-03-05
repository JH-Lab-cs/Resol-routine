String formatDayKey(DateTime nowLocal) {
  final year = nowLocal.year.toString().padLeft(4, '0');
  final month = nowLocal.month.toString().padLeft(2, '0');
  final day = nowLocal.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

void validateDayKey(String dayKey) {
  if (dayKey.length != 8) {
    throw FormatException('dayKey must be exactly 8 characters: "$dayKey"');
  }

  if (!RegExp(r'^\d{8}$').hasMatch(dayKey)) {
    throw FormatException('dayKey must contain digits only: "$dayKey"');
  }

  final year = int.parse(dayKey.substring(0, 4));
  final month = int.parse(dayKey.substring(4, 6));
  final day = int.parse(dayKey.substring(6, 8));

  final parsed = DateTime(year, month, day);
  final isValidDate =
      parsed.year == year && parsed.month == month && parsed.day == day;

  if (!isValidDate) {
    throw FormatException(
      'dayKey must represent a valid calendar date: "$dayKey"',
    );
  }
}
