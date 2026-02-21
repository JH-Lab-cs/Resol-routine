import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/database/db_text_limits.dart';
import '../../../core/domain/domain_enums.dart';
import '../../../core/security/hidden_unicode.dart';
import '../../today/data/attempt_payload.dart';
import 'models/report_schema_v1.dart';

class SharedReportSummary {
  const SharedReportSummary({
    required this.id,
    required this.source,
    required this.createdAt,
    required this.generatedAt,
    required this.latestDayKey,
    required this.track,
    required this.studentDisplayName,
    required this.dayCount,
    required this.totalSolvedCount,
    required this.totalWrongCount,
    required this.topWrongReasonTag,
  });

  final int id;
  final String source;
  final DateTime createdAt;
  final DateTime generatedAt;
  final String? latestDayKey;
  final String? track;
  final String? studentDisplayName;
  final int dayCount;
  final int totalSolvedCount;
  final int totalWrongCount;
  final String? topWrongReasonTag;
}

class SharedReportRecord {
  const SharedReportRecord({
    required this.id,
    required this.source,
    required this.payloadJson,
    required this.createdAt,
    required this.report,
  });

  final int id;
  final String source;
  final String payloadJson;
  final DateTime createdAt;
  final ReportSchema report;
}

class SharedReportsRepository {
  const SharedReportsRepository({required AppDatabase database})
    : _database = database;

  static const int _maxSourceLength = DbTextLimits.reportSourceMax;
  static const int _maxCanonicalPayloadLength = DbTextLimits.reportPayloadMax;
  static const int _maxRawPayloadLength = DbTextLimits.reportImportRawMaxChars;

  final AppDatabase _database;

  Future<int> importFromJson({
    required String source,
    required String payloadJson,
  }) async {
    final normalizedSource = _normalizeSource(source);
    final normalizedPayload = payloadJson.trim();

    _validateRawPayloadLength(normalizedPayload, path: 'payloadJson');

    final report = ReportSchema.decode(normalizedPayload, path: 'report');
    final canonicalPayload = report.encodeCompact();
    _validateCanonicalPayloadLength(canonicalPayload, path: 'report(encoded)');

    return _database
        .into(_database.sharedReports)
        .insert(
          SharedReportsCompanion.insert(
            source: normalizedSource,
            payloadJson: canonicalPayload,
          ),
        );
  }

  Future<List<SharedReportSummary>> listSummaries() async {
    final rows =
        await (_database.select(_database.sharedReports)..orderBy([
              (tbl) => OrderingTerm(
                expression: tbl.createdAt,
                mode: OrderingMode.desc,
              ),
              (tbl) =>
                  OrderingTerm(expression: tbl.id, mode: OrderingMode.desc),
            ]))
            .get();

    final summaries = <SharedReportSummary>[];
    for (final row in rows) {
      final report = _decodeStoredPayload(
        id: row.id,
        payloadJson: row.payloadJson,
      );
      summaries.add(
        SharedReportSummary(
          id: row.id,
          source: row.source,
          createdAt: row.createdAt,
          generatedAt: report.generatedAt,
          latestDayKey: _latestDayKey(report),
          track: _resolveTrack(report),
          studentDisplayName: report.student.displayName,
          dayCount: report.days.length,
          totalSolvedCount: _sumSolvedCount(report),
          totalWrongCount: _sumWrongCount(report),
          topWrongReasonTag: _resolveTopWrongReasonTag(report),
        ),
      );
    }

    return summaries;
  }

  Future<SharedReportRecord> loadById(int id) async {
    final row = await (_database.select(
      _database.sharedReports,
    )..where((tbl) => tbl.id.equals(id))).getSingle();

    final report = _decodeStoredPayload(
      id: row.id,
      payloadJson: row.payloadJson,
    );

    return SharedReportRecord(
      id: row.id,
      source: row.source,
      payloadJson: row.payloadJson,
      createdAt: row.createdAt,
      report: report,
    );
  }

  String _normalizeSource(String source) {
    final basename = p.basename(source.trim());
    if (basename.isEmpty) {
      throw const FormatException('source must be a non-empty file name.');
    }
    validateNoHiddenUnicode(basename, path: 'source');
    if (basename.length > _maxSourceLength) {
      throw FormatException('source length must be <= $_maxSourceLength.');
    }
    return basename;
  }

  void _validateRawPayloadLength(String payloadJson, {required String path}) {
    if (payloadJson.length < 2 || payloadJson.length > _maxRawPayloadLength) {
      throw FormatException(
        '$path length must be between 2 and $_maxRawPayloadLength characters.',
      );
    }
  }

  void _validateCanonicalPayloadLength(
    String payloadJson, {
    required String path,
  }) {
    if (payloadJson.length < 2 ||
        payloadJson.length > _maxCanonicalPayloadLength) {
      throw FormatException(
        '$path length must be between 2 and $_maxCanonicalPayloadLength characters.',
      );
    }
  }

  ReportSchema _decodeStoredPayload({
    required int id,
    required String payloadJson,
  }) {
    try {
      return ReportSchema.decode(
        payloadJson,
        path: 'sharedReports[$id].payloadJson',
      );
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid shared report payload at id=$id: ${error.message}',
      );
    }
  }

  String? _latestDayKey(ReportSchema report) {
    if (report.days.isEmpty) {
      return null;
    }

    String? latest;
    for (final day in report.days) {
      if (latest == null || day.dayKey.compareTo(latest) > 0) {
        latest = day.dayKey;
      }
    }
    return latest;
  }

  String? _resolveTrack(ReportSchema report) {
    if (report.days.isNotEmpty) {
      return report.days.first.track.dbValue;
    }
    return report.student.track?.dbValue;
  }

  int _sumSolvedCount(ReportSchema report) {
    var total = 0;
    for (final day in report.days) {
      total += day.solvedCount;
    }
    return total;
  }

  int _sumWrongCount(ReportSchema report) {
    var total = 0;
    for (final day in report.days) {
      total += day.wrongCount;
    }
    return total;
  }

  String? _resolveTopWrongReasonTag(ReportSchema report) {
    final counts = <String, int>{};
    for (final day in report.days) {
      for (final question in day.questions) {
        final tag = question.wrongReasonTag;
        if (tag == null) {
          continue;
        }
        counts.update(tag.dbValue, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    if (counts.isEmpty) {
      return null;
    }

    String? topTag;
    var topCount = -1;
    for (final tag in wrongReasonTags.map((tag) => tag.dbValue)) {
      final count = counts[tag] ?? 0;
      if (count > topCount) {
        topTag = tag;
        topCount = count;
      }
    }

    return topTag;
  }
}
