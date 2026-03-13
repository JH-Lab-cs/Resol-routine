import 'package:resol_routine/features/report/data/parent_report_models.dart';
import 'package:resol_routine/features/report/data/parent_report_repository.dart';

class FakeParentReportRepository implements ParentReportRepository {
  FakeParentReportRepository({
    ParentReportSummary? summary,
    ParentReportDetail? detail,
    this.summaryError,
    this.detailError,
  }) : _summary =
           summary ??
           ParentReportSummary(
             child: ParentReportChild(
               id: 'child-1',
               email: 'chulsoo@example.com',
               linkedAt: DateTime.utc(2026, 3, 13, 9),
             ),
             hasAnyReportData: true,
             dailySummary: const ParentReportDailySummary(
               dayKey: '2026-03-13',
               answeredCount: 6,
               correctCount: 5,
               wrongCount: 1,
             ),
             vocabSummary: ParentReportVocabSummary(
               dayKey: '2026-03-13',
               track: 'H1',
               totalCount: 20,
               correctCount: 16,
               wrongCount: 4,
               wrongVocabCount: 4,
               occurredAt: DateTime.utc(2026, 3, 13, 9, 30),
             ),
             weeklyMockSummary: ParentReportMockSummary(
               examType: 'WEEKLY',
               periodKey: '2026-W11',
               track: 'H1',
               plannedItems: 20,
               completedItems: 20,
               listeningCorrectCount: 8,
               readingCorrectCount: 9,
               wrongCount: 3,
               occurredAt: DateTime.utc(2026, 3, 13, 9, 40),
             ),
             monthlyMockSummary: null,
             recentActivity: const <ParentReportActivity>[
               ParentReportActivity(
                 activityType: 'DAILY',
                 dayKey: '2026-03-13',
                 periodKey: null,
                 track: 'H1',
                 answeredCount: 6,
                 correctCount: 5,
                 wrongCount: 1,
                 occurredAt: null,
               ),
             ],
           ),
       _detail =
           detail ??
           ParentReportDetail(
             child: ParentReportChild(
               id: 'child-1',
               email: 'chulsoo@example.com',
               linkedAt: DateTime.utc(2026, 3, 13, 9),
             ),
             hasAnyReportData: true,
             dailySummary: const ParentReportDailySummary(
               dayKey: '2026-03-13',
               answeredCount: 6,
               correctCount: 5,
               wrongCount: 1,
             ),
             weeklySummary: const ParentReportAggregateSummary(
               answeredCount: 12,
               correctCount: 10,
               wrongCount: 2,
               referenceKey: '2026-W11',
             ),
             monthlySummary: const ParentReportAggregateSummary(
               answeredCount: 20,
               correctCount: 16,
               wrongCount: 4,
               referenceKey: '2026-03',
             ),
             vocabSummary: ParentReportVocabSummary(
               dayKey: '2026-03-13',
               track: 'H1',
               totalCount: 20,
               correctCount: 16,
               wrongCount: 4,
               wrongVocabCount: 4,
               occurredAt: DateTime.utc(2026, 3, 13, 9, 30),
             ),
             weeklyMockSummary: ParentReportMockSummary(
               examType: 'WEEKLY',
               periodKey: '2026-W11',
               track: 'H1',
               plannedItems: 20,
               completedItems: 20,
               listeningCorrectCount: 8,
               readingCorrectCount: 9,
               wrongCount: 3,
               occurredAt: DateTime.utc(2026, 3, 13, 9, 40),
             ),
             monthlyMockSummary: null,
             recentTrend: const <ParentReportTrendPoint>[
               ParentReportTrendPoint(
                 dayKey: '2026-03-13',
                 answeredCount: 6,
                 correctCount: 5,
                 wrongCount: 1,
                 aggregatedAt: null,
               ),
             ],
             recentActivity: const <ParentReportActivity>[
               ParentReportActivity(
                 activityType: 'DAILY',
                 dayKey: '2026-03-13',
                 periodKey: null,
                 track: 'H1',
                 answeredCount: 6,
                 correctCount: 5,
                 wrongCount: 1,
                 occurredAt: null,
               ),
             ],
           );

  final ParentReportSummary _summary;
  final ParentReportDetail _detail;
  final ParentReportRepositoryException? summaryError;
  final ParentReportRepositoryException? detailError;

  @override
  Future<ParentReportSummary> fetchParentReportSummary({
    required String childId,
  }) async {
    if (summaryError case final error?) {
      throw error;
    }
    return _summary;
  }

  @override
  Future<ParentReportDetail> fetchParentReportDetail({
    required String childId,
  }) async {
    if (detailError case final error?) {
      throw error;
    }
    return _detail;
  }
}
