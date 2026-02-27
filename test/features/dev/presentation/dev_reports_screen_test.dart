import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/dev/presentation/dev_reports_screen.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

void main() {
  testWidgets('parent dev reports screen supports detail navigation and delete', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');

    final reportPayload = jsonEncode(_buildReportPayload());
    final reportId = await database.customInsert(
      'INSERT INTO shared_reports (source, payload_json, payload_sha256) VALUES (?, ?, ?)',
      variables: [
        Variable<String>('dev_report.json'),
        Variable<String>(reportPayload),
        Variable<String>(
          '1111111111111111111111111111111111111111111111111111111111111111',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: DevReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('dev-report-item-$reportId')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey<String>('dev-report-item-$reportId')));
    await tester.pumpAndSettle();
    expect(find.text('리포트 상세'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('dev-report-delete-$reportId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('dev-report-item-$reportId')),
      findsNothing,
    );
    expect(find.text('아직 가져온 리포트가 없습니다.'), findsOneWidget);
  });
}

Map<String, Object?> _buildReportPayload() {
  return <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': '2026-02-21T10:30:00.000Z',
    'student': <String, Object?>{
      'role': 'STUDENT',
      'displayName': '김철수',
      'track': 'H1',
    },
    'days': <Object?>[
      <String, Object?>{
        'dayKey': '20260220',
        'track': 'H1',
        'solvedCount': 1,
        'wrongCount': 0,
        'listeningCorrect': 1,
        'readingCorrect': 0,
        'wrongReasonCounts': <String, Object?>{},
        'questions': <Object?>[
          <String, Object?>{
            'questionId': 'Q-L-1',
            'skill': 'LISTENING',
            'typeTag': 'L1',
            'isCorrect': true,
          },
        ],
      },
    ],
  };
}
