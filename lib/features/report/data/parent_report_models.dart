class ParentReportChild {
  const ParentReportChild({
    required this.id,
    required this.email,
    required this.linkedAt,
  });

  final String id;
  final String email;
  final DateTime linkedAt;
}

class ParentReportDailySummary {
  const ParentReportDailySummary({
    required this.dayKey,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
  });

  final String dayKey;
  final int answeredCount;
  final int correctCount;
  final int wrongCount;
}

class ParentReportVocabSummary {
  const ParentReportVocabSummary({
    required this.dayKey,
    required this.track,
    required this.totalCount,
    required this.correctCount,
    required this.wrongCount,
    required this.wrongVocabCount,
    required this.occurredAt,
  });

  final String dayKey;
  final String track;
  final int totalCount;
  final int correctCount;
  final int wrongCount;
  final int wrongVocabCount;
  final DateTime occurredAt;
}

class ParentReportMockSummary {
  const ParentReportMockSummary({
    required this.examType,
    required this.periodKey,
    required this.track,
    required this.plannedItems,
    required this.completedItems,
    required this.listeningCorrectCount,
    required this.readingCorrectCount,
    required this.wrongCount,
    required this.occurredAt,
  });

  final String examType;
  final String periodKey;
  final String track;
  final int plannedItems;
  final int completedItems;
  final int listeningCorrectCount;
  final int readingCorrectCount;
  final int wrongCount;
  final DateTime occurredAt;
}

class ParentReportTrendPoint {
  const ParentReportTrendPoint({
    required this.dayKey,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    this.aggregatedAt,
  });

  final String dayKey;
  final int answeredCount;
  final int correctCount;
  final int wrongCount;
  final DateTime? aggregatedAt;
}

class ParentReportActivity {
  const ParentReportActivity({
    required this.activityType,
    required this.dayKey,
    required this.periodKey,
    required this.track,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.occurredAt,
  });

  final String activityType;
  final String? dayKey;
  final String? periodKey;
  final String? track;
  final int? answeredCount;
  final int? correctCount;
  final int? wrongCount;
  final DateTime? occurredAt;
}

class ParentReportSummary {
  const ParentReportSummary({
    required this.child,
    required this.hasAnyReportData,
    required this.dailySummary,
    required this.vocabSummary,
    required this.weeklyMockSummary,
    required this.monthlyMockSummary,
    required this.recentActivity,
  });

  final ParentReportChild child;
  final bool hasAnyReportData;
  final ParentReportDailySummary? dailySummary;
  final ParentReportVocabSummary? vocabSummary;
  final ParentReportMockSummary? weeklyMockSummary;
  final ParentReportMockSummary? monthlyMockSummary;
  final List<ParentReportActivity> recentActivity;
}

class ParentReportAggregateSummary {
  const ParentReportAggregateSummary({
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.referenceKey,
  });

  final int answeredCount;
  final int correctCount;
  final int wrongCount;
  final String referenceKey;
}

class ParentReportDetail {
  const ParentReportDetail({
    required this.child,
    required this.hasAnyReportData,
    required this.dailySummary,
    required this.weeklySummary,
    required this.monthlySummary,
    required this.vocabSummary,
    required this.weeklyMockSummary,
    required this.monthlyMockSummary,
    required this.recentTrend,
    required this.recentActivity,
  });

  final ParentReportChild child;
  final bool hasAnyReportData;
  final ParentReportDailySummary? dailySummary;
  final ParentReportAggregateSummary? weeklySummary;
  final ParentReportAggregateSummary? monthlySummary;
  final ParentReportVocabSummary? vocabSummary;
  final ParentReportMockSummary? weeklyMockSummary;
  final ParentReportMockSummary? monthlyMockSummary;
  final List<ParentReportTrendPoint> recentTrend;
  final List<ParentReportActivity> recentActivity;
}

class ParentReportRepositoryException implements Exception {
  const ParentReportRepositoryException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isServerUnavailable => (statusCode ?? 0) >= 500;

  @override
  String toString() =>
      'ParentReportRepositoryException($code, $statusCode): $message';
}

enum ParentReportEmptyReason { noLinkedChild, noData }

class ParentReportSummaryState {
  const ParentReportSummaryState._({
    required this.child,
    required this.summary,
    required this.emptyReason,
  });

  const ParentReportSummaryState.noLinkedChild()
    : this._(
        child: null,
        summary: null,
        emptyReason: ParentReportEmptyReason.noLinkedChild,
      );

  const ParentReportSummaryState.noData({
    required ParentReportChild child,
    required ParentReportSummary summary,
  }) : this._(
         child: child,
         summary: summary,
         emptyReason: ParentReportEmptyReason.noData,
       );

  const ParentReportSummaryState.success({
    required ParentReportChild child,
    required ParentReportSummary summary,
  }) : this._(child: child, summary: summary, emptyReason: null);

  final ParentReportChild? child;
  final ParentReportSummary? summary;
  final ParentReportEmptyReason? emptyReason;

  bool get hasData => summary != null && emptyReason == null;
}
