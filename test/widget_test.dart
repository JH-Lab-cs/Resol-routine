import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:resol_routine/app/app.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/time/day_key.dart';
import 'package:resol_routine/features/content_pack/application/content_pack_bootstrap.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/my/application/my_stats_providers.dart';
import 'package:resol_routine/features/my/presentation/my_screen.dart';
import 'package:resol_routine/features/settings/application/user_settings_providers.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import 'package:resol_routine/features/today/application/today_quiz_providers.dart';
import 'package:resol_routine/features/today/application/today_session_providers.dart';
import 'package:resol_routine/features/today/data/attempt_payload.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/today/presentation/quiz_flow_screen.dart';

void main() {
  testWidgets('opens quiz question from home CTA', (WidgetTester tester) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);

    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('지훈');
    await settingsRepository.updateTrack('M3');

    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('반가워요, 지훈 학생! 👋'));

    expect(find.text('반가워요, 지훈 학생! 👋'), findsOneWidget);
    expect(find.text('오늘 루틴 시작하기'), findsOneWidget);

    await tester.tap(find.text('오늘 루틴 시작하기'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('시작하기'));

    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('문제 1 / 6'));

    expect(find.text('문제 1 / 6'), findsOneWidget);
    expect(find.text('듣기'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows onboarding first and enters app after profile setup', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);

    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('카카오톡으로 계속하기'));
    expect(find.text('카카오톡으로 계속하기'), findsOneWidget);

    await tester.tap(find.text('카카오톡으로 계속하기'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('누가 사용하나요?'));

    await tester.tap(find.text('학생'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('내 학습 정보 설정'));
    expect(find.text('학습 학년 (추후 변경가능합니다)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '민수');
    await tester.enterText(find.byType(TextField).at(1), '20030201');
    await tester.pump();
    await tester.ensureVisible(find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    await _pumpUntilVisible(tester, find.text('반가워요, 민수 학생! 👋'));
    expect(find.text('반가워요, 민수 학생! 👋'), findsOneWidget);
  });

  testWidgets('parent onboarding requires only name input and lands on home', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);

    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('카카오톡으로 계속하기'));
    await tester.tap(find.text('카카오톡으로 계속하기'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('누가 사용하나요?'));

    await tester.tap(find.text('학부모'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('내 학습 정보 설정'));

    expect(find.text('학습 학년 (추후 변경가능합니다)'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '보호자');
    await tester.pump();
    await tester.ensureVisible(find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    await _pumpUntilVisible(tester, find.text('자녀 선택'));
    expect(find.text('자녀 선택'), findsOneWidget);
    expect(find.text('학습 리포트'), findsOneWidget);
    expect(find.text('자녀 연동 후 자동으로 표시됩니다.'), findsOneWidget);
    expect(find.text('단어장'), findsNothing);
    expect(find.text('오답 복습'), findsNothing);
  });

  testWidgets('parent app bar bell opens notification inbox', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);
    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');
    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('자녀 선택'));
    await tester.tap(find.byTooltip('알림함'));
    await tester.pumpAndSettle();

    expect(find.text('알림함 🔔'), findsOneWidget);
    expect(find.textContaining('숙제 마감 알림'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('알림함 🔔'), findsNothing);
  });

  testWidgets(
    'parent my screen renders settings and supports add child dialog',
    (WidgetTester tester) async {
      final sharedDb = AppDatabase(executor: NativeDatabase.memory());
      final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
      final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
      final settingsRepository = UserSettingsRepository(database: sharedDb);

      await settingsRepository.updateRole('PARENT');
      await settingsRepository.updateName('보호자');
      addTearDown(sharedDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(sharedDb),
            appBootstrapProvider.overrideWith((ref) async {}),
            todaySessionRepositoryProvider.overrideWithValue(
              fakeSessionRepository,
            ),
            todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
          ],
          child: const ResolRoutineApp(),
        ),
      );

      await _pumpUntilVisible(tester, find.text('자녀 선택'));
      await tester.tap(find.text('마이'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('학부모 설정'));

      expect(find.text('연결된 자녀'), findsOneWidget);
      expect(find.text('김철수'), findsOneWidget);
      expect(find.text('김영희'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '추가').first);
      await tester.pumpAndSettle();
      expect(find.text('자녀 추가하기'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '654321');
      await tester.tap(find.widgetWithText(FilledButton, '추가'));
      await tester.pumpAndSettle();

      expect(find.text('자녀를 추가했습니다.'), findsOneWidget);
      expect(find.text('자녀 3'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('학습 알림 설정'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('학습 알림 설정'), findsOneWidget);
    },
  );

  testWidgets(
    'changing settings does not replace app with entry loading gate',
    (WidgetTester tester) async {
      final sharedDb = AppDatabase(executor: NativeDatabase.memory());
      final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
      final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
      final settingsRepository = UserSettingsRepository(database: sharedDb);

      await settingsRepository.updateRole('STUDENT');
      await settingsRepository.updateName('지훈');
      await settingsRepository.updateTrack('H1');

      addTearDown(sharedDb.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(sharedDb),
            appBootstrapProvider.overrideWith((ref) async {}),
            todaySessionRepositoryProvider.overrideWithValue(
              fakeSessionRepository,
            ),
            todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
          ],
          child: const ResolRoutineApp(),
        ),
      );

      await _pumpUntilVisible(tester, find.text('반가워요, 지훈 학생! 👋'));
      expect(find.byType(NavigationBar), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ResolRoutineApp)),
      );

      await container.read(userSettingsProvider.notifier).updateTrack('H2');
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('카카오톡으로 계속하기'), findsNothing);

      await container
          .read(userSettingsProvider.notifier)
          .updateNotificationsEnabled(false);
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('카카오톡으로 계속하기'), findsNothing);
    },
  );

  testWidgets('logout clears account name and returns to onboarding gate', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);

    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('지훈');
    await settingsRepository.updateTrack('H1');

    addTearDown(sharedDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('반가워요, 지훈 학생! 👋'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResolRoutineApp)),
    );

    await container.read(userSettingsProvider.notifier).logout();
    await tester.pumpAndSettle();

    expect(find.text('카카오톡으로 계속하기'), findsOneWidget);
    final settingsAfterLogout = await settingsRepository.get();
    expect(settingsAfterLogout.displayName, '');
  });

  testWidgets('My 탭은 DB 기반 통계만 표시한다', (WidgetTester tester) async {
    late AppDatabase sharedDb;
    late _FakeTodaySessionRepository fakeSessionRepository;
    late _FakeTodayQuizRepository fakeQuizRepository;
    late int todayKey;
    late String questionId;

    await tester.runAsync(() async {
      sharedDb = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(sharedDb.close);

      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: sharedDb,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      final settingsRepository = UserSettingsRepository(database: sharedDb);
      await settingsRepository.updateRole('STUDENT');
      await settingsRepository.updateName('민수');
      await settingsRepository.updateTrack('M3');

      final firstQuestion = await (sharedDb.select(
        sharedDb.questions,
      )..limit(1)).getSingle();
      questionId = firstQuestion.id;
      final now = DateTime.now();
      todayKey = int.parse(formatDayKey(now));
      final dayMinus1 = int.parse(
        formatDayKey(now.subtract(const Duration(days: 1))),
      );
      final dayMinus3 = int.parse(
        formatDayKey(now.subtract(const Duration(days: 3))),
      );

      await sharedDb
          .into(sharedDb.dailySessions)
          .insert(
            DailySessionsCompanion.insert(
              dayKey: todayKey,
              track: const Value('M3'),
              plannedItems: const Value(6),
              completedItems: const Value(4),
              createdAt: Value(now.toUtc()),
            ),
          );
      await sharedDb
          .into(sharedDb.dailySessions)
          .insert(
            DailySessionsCompanion.insert(
              dayKey: dayMinus1,
              track: const Value('M3'),
              plannedItems: const Value(6),
              completedItems: const Value(6),
              createdAt: Value(now.subtract(const Duration(days: 1)).toUtc()),
            ),
          );
      await sharedDb
          .into(sharedDb.dailySessions)
          .insert(
            DailySessionsCompanion.insert(
              dayKey: dayMinus3,
              track: const Value('H2'),
              plannedItems: const Value(6),
              completedItems: const Value(6),
              createdAt: Value(now.subtract(const Duration(days: 3)).toUtc()),
            ),
          );

      await sharedDb
          .into(sharedDb.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: firstQuestion.id,
              userAnswerJson: '{}',
              isCorrect: true,
              attemptedAt: Value(now.toUtc()),
            ),
          );
      await sharedDb
          .into(sharedDb.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: firstQuestion.id,
              userAnswerJson: '{}',
              isCorrect: false,
              attemptedAt: Value(now.toUtc()),
            ),
          );
      await sharedDb
          .into(sharedDb.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: firstQuestion.id,
              userAnswerJson: '{}',
              isCorrect: false,
              attemptedAt: Value(now.toUtc()),
            ),
          );
    });

    fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          appBootstrapProvider.overrideWith((ref) async {}),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(fakeQuizRepository),
        ],
        child: const ResolRoutineApp(),
      ),
    );

    await _pumpUntilVisible(tester, find.text('반가워요, 민수 학생! 👋'));
    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 루틴 완료'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
    expect(find.text('연속 출석'), findsOneWidget);
    expect(find.text('2일'), findsOneWidget);
    expect(find.text('총 시도'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('총 오답'), findsOneWidget);
    expect(find.text('2회'), findsOneWidget);
    final myScrollable = find.descendant(
      of: find.byType(MyScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('학습 리포트'),
      240,
      scrollable: myScrollable.first,
    );
    await tester.pumpAndSettle();
    final reportCardFinder = find.byKey(
      const ValueKey<String>('my-storage-report'),
    );
    expect(reportCardFinder, findsOneWidget);
    expect(find.text('학습 리포트'), findsOneWidget);
    expect(find.text('이번주 외운 단어'), findsNothing);

    await tester.tap(reportCardFinder);
    await tester.pumpAndSettle();
    expect(find.text('리포트'), findsOneWidget);
    await _scrollUntilVisible(tester, find.text('JSON 리포트 공유'));
    expect(find.text('JSON 리포트 공유'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('총 오답'),
      -240,
      scrollable: myScrollable.first,
    );
    expect(find.text('총 오답'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResolRoutineApp)),
    );
    await tester.runAsync(() async {
      await sharedDb
          .into(sharedDb.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: questionId,
              userAnswerJson: '{}',
              isCorrect: false,
              attemptedAt: Value(DateTime.now().toUtc()),
            ),
          );
      await (sharedDb.update(sharedDb.dailySessions)..where(
            (tbl) => tbl.dayKey.equals(todayKey) & tbl.track.equals('M3'),
          ))
          .write(const DailySessionsCompanion(completedItems: Value(6)));
    });

    container.invalidate(myStatsProvider('M3'));
    await tester.pumpAndSettle();

    expect(find.text('6/6'), findsOneWidget);
    expect(find.text('2일'), findsOneWidget);
    expect(find.text('4회'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
  });

  testWidgets(
    'renders completion screen when resumed session is fully answered',
    (WidgetTester tester) async {
      late AppDatabase sharedDb;
      late _FixedNowSessionRepository fixedSessionRepository;
      late TodayQuizRepository quizRepository;

      await tester.runAsync(() async {
        sharedDb = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(sharedDb.close);

        final starterPackJson = await File(
          'assets/content_packs/starter_pack.json',
        ).readAsString();
        final seeder = ContentPackSeeder(
          database: sharedDb,
          source: MemoryContentPackSource(starterPackJson),
        );
        await seeder.seedOnFirstLaunch();

        final fixedNow = DateTime(2026, 2, 19, 8, 30);
        fixedSessionRepository = _FixedNowSessionRepository(sharedDb, fixedNow);
        quizRepository = TodayQuizRepository(database: sharedDb);

        final session = await fixedSessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: fixedNow,
        );
        for (final item in session.items) {
          final isCorrect = item.orderIndex.isEven;
          await quizRepository.saveAttemptIdempotent(
            sessionId: session.sessionId,
            questionId: item.questionId,
            selectedAnswer: 'A',
            isCorrect: isCorrect,
            wrongReasonTag: isCorrect ? null : WrongReasonTag.vocab,
          );
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(sharedDb),
            todaySessionRepositoryProvider.overrideWithValue(
              fixedSessionRepository,
            ),
            todayQuizRepositoryProvider.overrideWithValue(quizRepository),
          ],
          child: const MaterialApp(home: QuizFlowScreen(track: 'M3')),
        ),
      );

      await _pumpUntilVisible(tester, find.text('오늘 루틴 완료 🎉'));

      expect(find.text('오늘 루틴 완료 🎉'), findsOneWidget);
      expect(find.text('6문제 루틴을 끝냈어요.'), findsOneWidget);
      expect(find.text('오답 이유 Top 1'), findsOneWidget);
    },
  );

  testWidgets('shows empty state when quiz question list is empty', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(sharedDb.close);

    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final emptyQuizRepository = _EmptyTodayQuizRepository(sharedDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(sharedDb),
          todaySessionRepositoryProvider.overrideWithValue(
            fakeSessionRepository,
          ),
          todayQuizRepositoryProvider.overrideWithValue(emptyQuizRepository),
        ],
        child: const MaterialApp(home: QuizFlowScreen(track: 'M3')),
      ),
    );

    await _pumpUntilVisible(tester, find.text('문제를 불러오지 못했어요.'));

    expect(find.text('문제를 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('홈으로'), findsOneWidget);
  });
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Did not find expected widget after ${maxPumps * 50}ms.');
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class _FakeTodaySessionRepository extends TodaySessionRepository {
  _FakeTodaySessionRepository(AppDatabase database) : super(database: database);

  DailySessionBundle? _bundle;

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) async {
    final existing = _bundle;
    if (existing != null) {
      return existing;
    }

    final created = DailySessionBundle(
      sessionId: 1,
      dayKey: '20260219',
      track: track,
      plannedItems: 6,
      completedItems: 0,
      metadata: const DailySessionMetadata(),
      items: const [
        DailySessionItemBundle(
          orderIndex: 0,
          questionId: 'L-001',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 1,
          questionId: 'L-002',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 2,
          questionId: 'L-003',
          skill: 'LISTENING',
        ),
        DailySessionItemBundle(
          orderIndex: 3,
          questionId: 'R-001',
          skill: 'READING',
        ),
        DailySessionItemBundle(
          orderIndex: 4,
          questionId: 'R-002',
          skill: 'READING',
        ),
        DailySessionItemBundle(
          orderIndex: 5,
          questionId: 'R-003',
          skill: 'READING',
        ),
      ],
    );
    _bundle = created;
    return created;
  }

  @override
  Future<DailySessionBundle> saveSectionOrder({
    required int sessionId,
    required DailySectionOrder sectionOrder,
  }) async {
    final bundle = _bundle;
    if (bundle == null || bundle.sessionId != sessionId) {
      throw StateError('Daily session not found: $sessionId');
    }

    final listeningItems = bundle.items
        .where((item) => item.skill == 'LISTENING')
        .toList(growable: false);
    final readingItems = bundle.items
        .where((item) => item.skill == 'READING')
        .toList(growable: false);
    final orderedItems = sectionOrder == DailySectionOrder.listeningFirst
        ? <DailySessionItemBundle>[...listeningItems, ...readingItems]
        : <DailySessionItemBundle>[...readingItems, ...listeningItems];
    final normalizedItems = [
      for (var index = 0; index < orderedItems.length; index++)
        DailySessionItemBundle(
          orderIndex: index,
          questionId: orderedItems[index].questionId,
          skill: orderedItems[index].skill,
        ),
    ];

    final updated = DailySessionBundle(
      sessionId: bundle.sessionId,
      dayKey: bundle.dayKey,
      track: bundle.track,
      plannedItems: bundle.plannedItems,
      completedItems: bundle.completedItems,
      metadata: bundle.metadata.copyWith(sectionOrder: sectionOrder),
      items: normalizedItems,
    );
    _bundle = updated;
    return updated;
  }
}

class _FixedNowSessionRepository extends TodaySessionRepository {
  _FixedNowSessionRepository(AppDatabase database, this.fixedNow)
    : super(database: database);

  final DateTime fixedNow;

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) {
    return super.getOrCreateSession(track: track, nowLocal: fixedNow);
  }
}

class _FakeTodayQuizRepository extends TodayQuizRepository {
  _FakeTodayQuizRepository(AppDatabase database) : super(database: database);

  final List<QuizQuestionDetail> _questions = <QuizQuestionDetail>[
    QuizQuestionDetail(
      orderIndex: 0,
      questionId: 'L-001',
      skill: Skill.listening,
      typeTag: 'L1',
      track: Track.m3,
      prompt: 'What does the student order?',
      options: const OptionMap(
        a: 'Tea',
        b: 'Coffee',
        c: 'Milk',
        d: 'Juice',
        e: 'Water',
      ),
      answerKey: 'B',
      whyCorrectKo: '대화에서 coffee라고 말합니다.',
      whyWrongKo: const OptionMap(
        a: '주문 음료가 아닙니다.',
        b: '정답입니다.',
        c: '언급되지 않았습니다.',
        d: '언급되지 않았습니다.',
        e: '언급되지 않았습니다.',
      ),
      evidenceSentenceIds: <String>['ls_1'],
      sourceLines: <SourceLine>[
        SourceLine(
          sentenceIds: <String>['ls_1'],
          text: 'I would like a coffee, please.',
          index: 0,
          speaker: 'S1',
        ),
      ],
    ),
    ..._fillerQuestions,
  ];

  @override
  Future<List<QuizQuestionDetail>> loadSessionQuestions(int sessionId) async {
    return _questions;
  }

  @override
  Future<Map<String, AttemptPayload>> loadSessionAttempts(int sessionId) async {
    return <String, AttemptPayload>{};
  }

  @override
  Future<int> findFirstUnansweredOrderIndex({required int sessionId}) async {
    return 0;
  }

  @override
  Future<SessionProgress> loadSessionProgress(int sessionId) async {
    return const SessionProgress(
      completed: 0,
      listeningCompleted: 0,
      readingCompleted: 0,
    );
  }
}

class _EmptyTodayQuizRepository extends TodayQuizRepository {
  _EmptyTodayQuizRepository(AppDatabase database) : super(database: database);

  @override
  Future<List<QuizQuestionDetail>> loadSessionQuestions(int sessionId) async {
    return const <QuizQuestionDetail>[];
  }

  @override
  Future<Map<String, AttemptPayload>> loadSessionAttempts(int sessionId) async {
    return <String, AttemptPayload>{};
  }

  @override
  Future<int> findFirstUnansweredOrderIndex({required int sessionId}) async {
    return 0;
  }

  @override
  Future<SessionProgress> loadSessionProgress(int sessionId) async {
    return const SessionProgress(
      completed: 0,
      listeningCompleted: 0,
      readingCompleted: 0,
    );
  }
}

final List<QuizQuestionDetail> _fillerQuestions =
    List<QuizQuestionDetail>.generate(
      5,
      (index) => QuizQuestionDetail(
        orderIndex: index + 1,
        questionId: 'Q-${index + 2}',
        skill: index < 2 ? Skill.listening : Skill.reading,
        typeTag: index < 2 ? 'L2' : 'R2',
        track: Track.m3,
        prompt: 'Filler question ${index + 2}',
        options: const OptionMap(a: 'A', b: 'B', c: 'C', d: 'D', e: 'E'),
        answerKey: 'A',
        whyCorrectKo: '정답 해설',
        whyWrongKo: const OptionMap(
          a: '정답',
          b: '오답',
          c: '오답',
          d: '오답',
          e: '오답',
        ),
        evidenceSentenceIds: const <String>['s1'],
        sourceLines: <SourceLine>[
          SourceLine(
            sentenceIds: const <String>['s1'],
            text: 'Sample source line',
            index: 0,
            speaker: index < 2 ? 'S1' : null,
          ),
        ],
      ),
    );
