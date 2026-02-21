import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/models/report_schema_v1.dart';
import '../data/report_export_repository.dart';
import '../data/shared_reports_repository.dart';

final reportExportRepositoryProvider = Provider<ReportExportRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return ReportExportRepository(database: database);
});

final sharedReportsRepositoryProvider = Provider<SharedReportsRepository>((
  Ref ref,
) {
  final database = ref.watch(appDatabaseProvider);
  return SharedReportsRepository(database: database);
});

final studentCumulativeReportProvider =
    FutureProvider.family<ReportSchema, String>((Ref ref, String track) {
      final repository = ref.watch(reportExportRepositoryProvider);
      return repository.buildCumulativeReport(track: track);
    });

final studentTodayReportProvider = FutureProvider.family<ReportDay?, String>((
  Ref ref,
  String track,
) {
  final repository = ref.watch(reportExportRepositoryProvider);
  return repository.buildTodayReport(track: track);
});

final sharedReportSummariesProvider = FutureProvider<List<SharedReportSummary>>(
  (Ref ref) {
    final repository = ref.watch(sharedReportsRepositoryProvider);
    return repository.listSummaries();
  },
);

final sharedReportByIdProvider = FutureProvider.family<SharedReportRecord, int>(
  (Ref ref, int id) {
    final repository = ref.watch(sharedReportsRepositoryProvider);
    return repository.loadById(id);
  },
);
