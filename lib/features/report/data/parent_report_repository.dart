import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';
import 'parent_report_models.dart';

class ParentReportRepository {
  ParentReportRepository({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<ParentReportSummary> fetchParentReportSummary({
    required String childId,
  }) async {
    final response = await _authRepository.authorizedGet(
      '/reports/children/$childId/summary',
    );
    final body = _requireSuccessBody(response);
    return ParentReportSummary(
      child: _parseChild(_requiredMap(body, 'child')),
      hasAnyReportData: _requiredBool(body, 'has_any_report_data'),
      dailySummary: _parseDailySummary(body['daily_summary']),
      vocabSummary: _parseVocabSummary(body['vocab_summary']),
      weeklyMockSummary: _parseMockSummary(body['weekly_mock_summary']),
      monthlyMockSummary: _parseMockSummary(body['monthly_mock_summary']),
      recentActivity: _parseActivities(body['recent_activity']),
    );
  }

  Future<ParentReportDetail> fetchParentReportDetail({
    required String childId,
  }) async {
    final response = await _authRepository.authorizedGet(
      '/reports/children/$childId/detail',
    );
    final body = _requireSuccessBody(response);
    return ParentReportDetail(
      child: _parseChild(_requiredMap(body, 'child')),
      hasAnyReportData: _requiredBool(body, 'has_any_report_data'),
      dailySummary: _parseDailySummary(body['daily_summary']),
      weeklySummary: _parseAggregateSummary(
        body['weekly_summary'],
        keyField: 'week_key',
      ),
      monthlySummary: _parseAggregateSummary(
        body['monthly_summary'],
        keyField: 'period_key',
      ),
      vocabSummary: _parseVocabSummary(body['vocab_summary']),
      weeklyMockSummary: _parseMockSummary(body['weekly_mock_summary']),
      monthlyMockSummary: _parseMockSummary(body['monthly_mock_summary']),
      recentTrend: _parseTrendPoints(body['recent_trend']),
      recentActivity: _parseActivities(body['recent_activity']),
    );
  }

  Map<String, Object?> _requireSuccessBody(JsonApiResponse response) {
    if (response.statusCode >= 400) {
      throw _toException(response);
    }
    final body = response.bodyAsMap;
    if (body.isEmpty) {
      throw ParentReportRepositoryException(
        code: 'invalid_response',
        message: 'The server returned an empty response body.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  ParentReportRepositoryException _toException(JsonApiResponse response) {
    final body = response.bodyAsMap;
    final code =
        body['errorCode']?.toString() ??
        body['detail']?.toString() ??
        'http_${response.statusCode}';
    final message = body['detail']?.toString() ?? 'Request failed.';
    return ParentReportRepositoryException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  ParentReportChild _parseChild(Map<String, Object?> body) {
    return ParentReportChild(
      id: _requiredString(body, 'id'),
      email: _requiredString(body, 'email'),
      linkedAt: _requiredDateTime(body, 'linked_at'),
    );
  }

  ParentReportDailySummary? _parseDailySummary(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    final body = _requireMapValue(rawValue, 'daily_summary');
    return ParentReportDailySummary(
      dayKey: _requiredString(body, 'day_key'),
      answeredCount: _requiredInt(body, 'answered_count'),
      correctCount: _requiredInt(body, 'correct_count'),
      wrongCount: _requiredInt(body, 'wrong_count'),
    );
  }

  ParentReportAggregateSummary? _parseAggregateSummary(
    Object? rawValue, {
    required String keyField,
  }) {
    if (rawValue == null) {
      return null;
    }
    final body = _requireMapValue(rawValue, keyField);
    return ParentReportAggregateSummary(
      answeredCount: _requiredInt(body, 'answered_count'),
      correctCount: _requiredInt(body, 'correct_count'),
      wrongCount: _requiredInt(body, 'wrong_count'),
      referenceKey: _requiredString(body, keyField),
    );
  }

  ParentReportVocabSummary? _parseVocabSummary(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    final body = _requireMapValue(rawValue, 'vocab_summary');
    return ParentReportVocabSummary(
      dayKey: _requiredString(body, 'day_key'),
      track: _requiredString(body, 'track'),
      totalCount: _requiredInt(body, 'total_count'),
      correctCount: _requiredInt(body, 'correct_count'),
      wrongCount: _requiredInt(body, 'wrong_count'),
      wrongVocabCount: _requiredInt(body, 'wrong_vocab_count'),
      occurredAt: _requiredDateTime(body, 'occurred_at'),
    );
  }

  ParentReportMockSummary? _parseMockSummary(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    final body = _requireMapValue(rawValue, 'mock_summary');
    return ParentReportMockSummary(
      examType: _requiredString(body, 'exam_type'),
      periodKey: _requiredString(body, 'period_key'),
      track: _requiredString(body, 'track'),
      plannedItems: _requiredInt(body, 'planned_items'),
      completedItems: _requiredInt(body, 'completed_items'),
      listeningCorrectCount: _requiredInt(body, 'listening_correct_count'),
      readingCorrectCount: _requiredInt(body, 'reading_correct_count'),
      wrongCount: _requiredInt(body, 'wrong_count'),
      occurredAt: _requiredDateTime(body, 'occurred_at'),
    );
  }

  List<ParentReportTrendPoint> _parseTrendPoints(Object? rawValue) {
    if (rawValue is! List) {
      return const <ParentReportTrendPoint>[];
    }
    return rawValue
        .map((Object? item) {
          final body = _requireMapValue(item, 'recent_trend');
          return ParentReportTrendPoint(
            dayKey: _requiredString(body, 'day_key'),
            answeredCount: _requiredInt(body, 'answered_count'),
            correctCount: _requiredInt(body, 'correct_count'),
            wrongCount: _requiredInt(body, 'wrong_count'),
            aggregatedAt: _optionalDateTime(body, 'aggregated_at'),
          );
        })
        .toList(growable: false);
  }

  List<ParentReportActivity> _parseActivities(Object? rawValue) {
    if (rawValue is! List) {
      return const <ParentReportActivity>[];
    }
    return rawValue
        .map((Object? item) {
          final body = _requireMapValue(item, 'recent_activity');
          return ParentReportActivity(
            activityType: _requiredString(body, 'activity_type'),
            dayKey: _optionalString(body, 'day_key'),
            periodKey: _optionalString(body, 'period_key'),
            track: _optionalString(body, 'track'),
            answeredCount: _optionalInt(body, 'answered_count'),
            correctCount: _optionalInt(body, 'correct_count'),
            wrongCount: _optionalInt(body, 'wrong_count'),
            occurredAt: _optionalDateTime(body, 'occurred_at'),
          );
        })
        .toList(growable: false);
  }

  Map<String, Object?> _requiredMap(Map<String, Object?> body, String key) {
    final value = body[key];
    return _requireMapValue(value, key);
  }

  Map<String, Object?> _requireMapValue(Object? rawValue, String key) {
    if (rawValue is Map<String, Object?>) {
      return rawValue;
    }
    if (rawValue is Map) {
      return Map<String, Object?>.from(rawValue);
    }
    throw ParentReportRepositoryException(
      code: 'invalid_response',
      message: 'Missing required object field: $key',
    );
  }

  String _requiredString(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw ParentReportRepositoryException(
      code: 'invalid_response',
      message: 'Missing required string field: $key',
    );
  }

  String? _optionalString(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  int _requiredInt(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw ParentReportRepositoryException(
      code: 'invalid_response',
      message: 'Missing required integer field: $key',
    );
  }

  int? _optionalInt(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  bool _requiredBool(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is bool) {
      return value;
    }
    throw ParentReportRepositoryException(
      code: 'invalid_response',
      message: 'Missing required boolean field: $key',
    );
  }

  DateTime _requiredDateTime(Map<String, Object?> body, String key) {
    final raw = _requiredString(body, key);
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      throw ParentReportRepositoryException(
        code: 'invalid_response',
        message: 'Invalid datetime field: $key',
      );
    }
  }

  DateTime? _optionalDateTime(Map<String, Object?> body, String key) {
    final raw = _optionalString(body, key);
    if (raw == null) {
      return null;
    }
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      throw ParentReportRepositoryException(
        code: 'invalid_response',
        message: 'Invalid datetime field: $key',
      );
    }
  }
}
