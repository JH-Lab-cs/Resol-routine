import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_repository.dart';
import 'package:resol_routine/features/report/data/parent_report_models.dart';
import 'package:resol_routine/features/report/data/parent_report_repository.dart';

void main() {
  group('ParentReportRepository', () {
    test('summary fetch success parses backend payload', () async {
      final repository = ParentReportRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedGet: (String path) async {
            expect(path, '/reports/children/child-1/summary');
            return _jsonResponse(200, <String, Object?>{
              'child': <String, Object?>{
                'id': 'child-1',
                'email': 'chulsoo@example.com',
                'linked_at': '2026-03-13T09:00:00Z',
              },
              'has_any_report_data': true,
              'daily_summary': <String, Object?>{
                'day_key': '2026-03-13',
                'answered_count': 6,
                'correct_count': 5,
                'wrong_count': 1,
              },
              'vocab_summary': null,
              'weekly_mock_summary': null,
              'monthly_mock_summary': null,
              'recent_activity': <Object?>[],
            });
          },
        ),
      );

      final summary = await repository.fetchParentReportSummary(
        childId: 'child-1',
      );

      expect(summary.child.email, 'chulsoo@example.com');
      expect(summary.dailySummary?.correctCount, 5);
      expect(summary.hasAnyReportData, isTrue);
    });

    test('detail fetch success parses backend payload', () async {
      final repository = ParentReportRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedGet: (String path) async {
            expect(path, '/reports/children/child-1/detail');
            return _jsonResponse(200, <String, Object?>{
              'child': <String, Object?>{
                'id': 'child-1',
                'email': 'chulsoo@example.com',
                'linked_at': '2026-03-13T09:00:00Z',
              },
              'has_any_report_data': true,
              'daily_summary': <String, Object?>{
                'day_key': '2026-03-13',
                'answered_count': 6,
                'correct_count': 5,
                'wrong_count': 1,
              },
              'weekly_summary': <String, Object?>{
                'week_key': '2026-W11',
                'answered_count': 12,
                'correct_count': 10,
                'wrong_count': 2,
              },
              'monthly_summary': null,
              'vocab_summary': null,
              'weekly_mock_summary': null,
              'monthly_mock_summary': null,
              'recent_trend': <Object?>[
                <String, Object?>{
                  'day_key': '2026-03-13',
                  'answered_count': 6,
                  'correct_count': 5,
                  'wrong_count': 1,
                  'aggregated_at': '2026-03-13T10:00:00Z',
                },
              ],
              'recent_activity': <Object?>[],
            });
          },
        ),
      );

      final detail = await repository.fetchParentReportDetail(
        childId: 'child-1',
      );

      expect(detail.weeklySummary?.referenceKey, '2026-W11');
      expect(detail.recentTrend, hasLength(1));
    });

    test('server error becomes structured repository exception', () async {
      final repository = ParentReportRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedGet: (String path) async {
            return _jsonResponse(503, <String, Object?>{
              'detail': 'service_unavailable',
              'errorCode': 'service_unavailable',
            });
          },
        ),
      );

      await expectLater(
        repository.fetchParentReportSummary(childId: 'child-1'),
        throwsA(
          isA<ParentReportRepositoryException>()
              .having((error) => error.code, 'code', 'service_unavailable')
              .having((error) => error.statusCode, 'statusCode', 503),
        ),
      );
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.onAuthorizedGet});

  final Future<JsonApiResponse> Function(String path)? onAuthorizedGet;

  @override
  Future<JsonApiResponse> authorizedGet(
    String path, {
    bool retryOnUnauthorized = true,
  }) {
    final handler = onAuthorizedGet;
    if (handler == null) {
      throw UnimplementedError(
        'authorizedGet was not configured for this test.',
      );
    }
    return handler(path);
  }

  @override
  Future<JsonApiResponse> authorizedPost(
    String path, {
    Object? body,
    bool retryOnUnauthorized = true,
  }) async => throw UnimplementedError();

  @override
  Future<void> clearSession() async => throw UnimplementedError();

  @override
  Future<AuthUserProfile> fetchCurrentUser({
    bool retryOnUnauthorized = true,
  }) async => throw UnimplementedError();

  @override
  Future<AuthSession> refreshSession() async => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => throw UnimplementedError();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> signOut() async => throw UnimplementedError();
}

JsonApiResponse _jsonResponse(int statusCode, Map<String, Object?> body) {
  return JsonApiResponse(
    statusCode: statusCode,
    body: body,
    rawBody: jsonEncode(body),
  );
}
