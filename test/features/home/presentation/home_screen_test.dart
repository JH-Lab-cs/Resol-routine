import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/home/presentation/home_screen.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

void main() {
  testWidgets('shows parent home skeleton while report summaries load', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final summariesCompleter = Completer<List<SharedReportSummary>>();

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedReportSummariesProvider.overrideWith((ref) {
            return summariesCompleter.future;
          }),
        ],
        child: MaterialApp(
          home: HomeScreen(
            onOpenQuiz: () {},
            onOpenVocab: () {},
            onOpenTodayVocabQuiz: () {},
            onOpenWrongNotes: () {},
            onOpenMy: () {},
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey<String>('parent-home-loading-skeleton')),
      findsOneWidget,
    );

    summariesCompleter.complete(const <SharedReportSummary>[]);
    await tester.pumpAndSettle();
  });

  testWidgets('parent home layout stays stable at text scale 1.4', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedReportSummariesProvider.overrideWith((ref) async {
            return <SharedReportSummary>[
              SharedReportSummary(
                id: 1,
                source: 'resolroutine_report_20260228_M3.json',
                createdAt: DateTime.utc(2026, 2, 28, 12, 0),
                generatedAt: DateTime.utc(2026, 2, 28, 12, 0),
                latestDayKey: '20260228',
                track: 'M3',
                studentDisplayName: '아주아주긴학생이름테스트용',
                dayCount: 7,
                totalSolvedCount: 30,
                totalWrongCount: 8,
                topWrongReasonTag: 'VOCAB',
              ),
            ];
          }),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: MaterialApp(
            home: HomeScreen(
              onOpenQuiz: () {},
              onOpenVocab: () {},
              onOpenTodayVocabQuiz: () {},
              onOpenWrongNotes: () {},
              onOpenMy: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('가정 리포트'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
