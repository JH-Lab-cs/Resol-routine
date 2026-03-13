import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/dev/application/dev_tools_providers.dart';
import 'package:resol_routine/features/family/application/family_providers.dart';
import 'package:resol_routine/features/family/data/family_repository.dart';
import 'package:resol_routine/features/home/application/home_providers.dart';
import 'package:resol_routine/features/home/presentation/home_screen.dart';
import 'package:resol_routine/features/mock_exam/application/mock_exam_providers.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_period_key.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import '../../../test_helpers/fake_auth_session.dart';
import '../../../test_helpers/fake_family_repository.dart';

void main() {
  testWidgets('shows child selector and add action in parent home', (
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
          devToolsVisibleProvider.overrideWith((ref) => false),
          signedInAuthOverride(
            role: AuthUserRole.parent,
            email: 'parent@example.com',
          ),
          familyRepositoryProvider.overrideWithValue(
            FakeFamilyRepository(
              snapshot: parentFamilySnapshot(
                linkedChildren: <FamilyLinkedUserSummary>[
                  fakeLinkedFamilyUser(
                    id: 'child-1',
                    email: 'chulsoo@example.com',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: HomeScreen(
            onOpenQuiz: () {},
            onOpenWeeklyMockExam: () {},
            onOpenMonthlyMockExam: () {},
            onOpenVocab: () {},
            onOpenTodayVocabQuiz: () {},
            onOpenWrongNotes: () {},
            onOpenWrongReview: () {},
            onOpenMy: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('자녀 선택'), findsOneWidget);
    expect(find.text('학습 리포트'), findsOneWidget);
    expect(find.text('chulsoo'), findsAtLeastNWidgets(1));
    expect(find.text('최근 학습 활동'), findsNothing);
    expect(find.text('추가'), findsAtLeastNWidgets(1));
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
          devToolsVisibleProvider.overrideWith((ref) => false),
          signedInAuthOverride(
            role: AuthUserRole.parent,
            email: 'parent@example.com',
          ),
          familyRepositoryProvider.overrideWithValue(
            FakeFamilyRepository(
              snapshot: parentFamilySnapshot(
                linkedChildren: <FamilyLinkedUserSummary>[
                  fakeLinkedFamilyUser(
                    id: 'child-1',
                    email: 'chulsoo@example.com',
                  ),
                ],
              ),
            ),
          ),
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
              onOpenWrongReview: () {},
              onOpenMy: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('자녀 선택'), findsOneWidget);
    expect(find.text('chulsoo'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shows dev reports test button when parent dev tools are visible',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final settingsRepository = UserSettingsRepository(database: database);
      await settingsRepository.updateRole('PARENT');
      await settingsRepository.updateName('보호자');

      var openDevReportsCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            devToolsVisibleProvider.overrideWith((ref) => true),
            signedInAuthOverride(
              role: AuthUserRole.parent,
              email: 'parent@example.com',
            ),
            familyRepositoryProvider.overrideWithValue(
              FakeFamilyRepository(
                snapshot: parentFamilySnapshot(
                  linkedChildren: <FamilyLinkedUserSummary>[
                    fakeLinkedFamilyUser(
                      id: 'child-1',
                      email: 'chulsoo@example.com',
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onOpenQuiz: () {},
              onOpenWeeklyMockExam: () {},
              onOpenMonthlyMockExam: () {},
              onOpenVocab: () {},
              onOpenTodayVocabQuiz: () {},
              onOpenWrongNotes: () {},
              onOpenWrongReview: () {},
              onOpenMy: () {},
              onOpenDevReports: () {
                openDevReportsCount += 1;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('parent-home-dev-reports-button')),
      );
      await tester.pumpAndSettle();

      expect(openDevReportsCount, 1);
    },
  );

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
                onOpenWrongReview: () {},
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
        matching: find.textContaining('듣기 10 + 독해 10'),
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

  testWidgets(
    'home weekly card returns to start state after deleting session',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final settingsRepository = UserSettingsRepository(database: database);
      await settingsRepository.updateRole('STUDENT');
      await settingsRepository.updateName('학생');
      await settingsRepository.updateTrack('M3');

      final nowLocal = DateTime.now();
      final weeklyPeriodKey = buildMockExamPeriodKey(
        type: MockExamType.weekly,
        nowLocal: nowLocal,
      );
      final sessionRepository = MockExamSessionRepository(database: database);
      final completedSessionId = await database
          .into(database.mockExamSessions)
          .insert(
            MockExamSessionsCompanion.insert(
              examType: MockExamType.weekly.dbValue,
              periodKey: weeklyPeriodKey,
              track: 'M3',
              plannedItems: 20,
              completedItems: const Value(20),
              completedAt: Value(nowLocal.toUtc()),
            ),
          );

      var homeBuildSeed = 0;

      Future<void> pumpHome() async {
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey<int>(homeBuildSeed),
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
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
                  onOpenWeeklyMockExam: () {},
                  onOpenMonthlyMockExam: () {},
                  onOpenVocab: () {},
                  onOpenTodayVocabQuiz: () {},
                  onOpenWrongNotes: () {},
                  onOpenWrongReview: () {},
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
          matching: find.textContaining('결과 보기'),
        ),
        findsOneWidget,
      );

      await sessionRepository.deleteSessionById(completedSessionId);
      homeBuildSeed += 1;
      await pumpHome();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('home-mock-weekly-card')),
          matching: find.textContaining('듣기 10 + 독해 10'),
        ),
        findsOneWidget,
      );
    },
  );
}
