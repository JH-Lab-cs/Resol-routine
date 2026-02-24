import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/home/application/home_providers.dart';
import 'package:resol_routine/features/home/presentation/home_screen.dart';
import 'package:resol_routine/features/mock_exam/application/mock_exam_providers.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';

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
            onOpenWeeklyMockExam: () {},
            onOpenMonthlyMockExam: () {},
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
              onOpenWeeklyMockExam: () {},
              onOpenMonthlyMockExam: () {},
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

  testWidgets('student mock cards show start, continue, and result states', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('학생');
    await settingsRepository.updateTrack('M3');

    MockExamSessionSummary? weeklySummary;

    var weeklyOpenCount = 0;
    var monthlyOpenCount = 0;

    Future<void> pumpHome() async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<int>(weeklySummary?.completedItems ?? -1),
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            mockExamCurrentSummaryProvider.overrideWith((ref, query) async {
              if (query.type == MockExamType.weekly) {
                return weeklySummary;
              }
              return null;
            }),
            homeRoutineSummaryProvider.overrideWith((ref, track) async {
              return const HomeRoutineSummary(
                session: DailySessionBundle(
                  sessionId: 1,
                  dayKey: '20260301',
                  track: 'M3',
                  plannedItems: 6,
                  completedItems: 0,
                  items: <DailySessionItemBundle>[
                    DailySessionItemBundle(
                      orderIndex: 0,
                      questionId: 'Q-MOCK-1',
                      skill: 'LISTENING',
                    ),
                  ],
                ),
                progress: SessionProgress(
                  completed: 0,
                  listeningCompleted: 0,
                  readingCompleted: 0,
                ),
              );
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                onOpenQuiz: () {},
                onOpenWeeklyMockExam: () {
                  weeklyOpenCount += 1;
                },
                onOpenMonthlyMockExam: () {
                  monthlyOpenCount += 1;
                },
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('home-mock-weekly-card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await pumpHome();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-mock-weekly-card')),
        matching: find.textContaining('시작하기'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('home-mock-weekly-card')),
    );
    await tester.pumpAndSettle();
    expect(weeklyOpenCount, 1);
    expect(monthlyOpenCount, 0);

    weeklySummary = MockExamSessionSummary(
      sessionId: 100,
      examType: MockExamType.weekly,
      periodKey: '2026W09',
      track: 'M3',
      plannedItems: 20,
      completedItems: 1,
      correctCount: 1,
      wrongCount: 0,
      updatedAt: DateTime.utc(2026, 3, 1, 10, 0),
      completedAt: null,
    );

    await pumpHome();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-mock-weekly-card')),
        matching: find.textContaining('이어하기'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('home-mock-weekly-card')),
    );
    await tester.pumpAndSettle();
    expect(weeklyOpenCount, 2);

    weeklySummary = MockExamSessionSummary(
      sessionId: 101,
      examType: MockExamType.weekly,
      periodKey: '2026W09',
      track: 'M3',
      plannedItems: 20,
      completedItems: 20,
      correctCount: 18,
      wrongCount: 2,
      updatedAt: DateTime.utc(2026, 3, 1, 11, 0),
      completedAt: DateTime.utc(2026, 3, 1, 11, 0),
    );

    await pumpHome();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-mock-weekly-card')),
        matching: find.textContaining('결과 보기'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('home-mock-weekly-card')),
    );
    await tester.pumpAndSettle();
    expect(weeklyOpenCount, 2);
    expect(find.text('주간 모의고사 결과'), findsAtLeastNWidgets(1));
  });
}
