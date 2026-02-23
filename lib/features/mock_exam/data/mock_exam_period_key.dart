import '../../../core/domain/domain_enums.dart';

String buildMockExamPeriodKey({
  required MockExamType type,
  required DateTime nowLocal,
}) {
  final seoulDateTime = nowLocal.toUtc().add(const Duration(hours: 9));
  final seoulDate = DateTime.utc(
    seoulDateTime.year,
    seoulDateTime.month,
    seoulDateTime.day,
  );

  switch (type) {
    case MockExamType.weekly:
      return _formatWeeklyPeriodKey(seoulDate);
    case MockExamType.monthly:
      return _formatMonthlyPeriodKey(seoulDate);
  }
}

void validateMockExamPeriodKey({
  required MockExamType type,
  required String periodKey,
}) {
  switch (type) {
    case MockExamType.weekly:
      final weeklyMatch = RegExp(
        r'^\d{4}W(0[1-9]|[1-4]\d|5[0-3])$',
      ).hasMatch(periodKey);
      if (!weeklyMatch) {
        throw FormatException(
          'weekly periodKey must match YYYYWww: "$periodKey"',
        );
      }
      return;
    case MockExamType.monthly:
      final monthlyMatch = RegExp(r'^\d{6}$').hasMatch(periodKey);
      if (!monthlyMatch) {
        throw FormatException(
          'monthly periodKey must match YYYYMM: "$periodKey"',
        );
      }
      final month = int.parse(periodKey.substring(4, 6));
      if (month < 1 || month > 12) {
        throw FormatException(
          'monthly periodKey month must be between 01 and 12: "$periodKey"',
        );
      }
      return;
  }
}

String _formatMonthlyPeriodKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$year$month';
}

String _formatWeeklyPeriodKey(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final isoYear = thursday.year;
  final weekOneThursday = _isoWeekOneThursday(isoYear);
  final week = 1 + (thursday.difference(weekOneThursday).inDays ~/ 7);
  final weekText = week.toString().padLeft(2, '0');
  return '${isoYear}W$weekText';
}

DateTime _isoWeekOneThursday(int isoYear) {
  final jan4 = DateTime.utc(isoYear, 1, 4);
  return jan4.add(Duration(days: 4 - jan4.weekday));
}
