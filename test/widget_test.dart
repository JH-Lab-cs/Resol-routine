import 'dart:convert';
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
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
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

    await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 지훈! 👋'));

    expect(find.text('오늘도 화이팅, 지훈! 👋'), findsOneWidget);
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

    await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 민수! 👋'));
    expect(find.text('오늘도 화이팅, 민수! 👋'), findsOneWidget);
  });

  testWidgets('parent onboarding requires only name input', (
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

    await _pumpUntilVisible(tester, find.text('리포트 가져오기'));
    expect(find.text('리포트 가져오기'), findsOneWidget);
  });

  testWidgets('parent home renders imported reports and opens detail', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);
    final sharedReportsRepository = SharedReportsRepository(database: sharedDb);

    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');
    await sharedReportsRepository.importFromJson(
      source: 'resolroutine_report_20260221_M3.json',
      payloadJson: _sampleSharedReportJson(),
    );

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

    await _pumpUntilVisible(tester, find.text('리포트 가져오기'));
    await _pumpUntilVisible(tester, find.textContaining('오답 1개'));
    expect(find.textContaining('오답 1개'), findsOneWidget);

    final titleFinder = find.text('민수');
    final fallbackTitleFinder = find.text(
      'resolroutine_report_20260221_M3.json',
    );
    if (titleFinder.evaluate().isNotEmpty) {
      await tester.tap(titleFinder);
    } else {
      await tester.tap(fallbackTitleFinder);
    }
    await tester.pumpAndSettle();

    expect(find.text('리포트 상세'), findsOneWidget);
    expect(find.textContaining('총 오답 1문항'), findsOneWidget);
  });

  testWidgets(
    'parent detail day card is collapsed by default and expands on tap',
    (WidgetTester tester) async {
      final sharedDb = AppDatabase(executor: NativeDatabase.memory());
      final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
      final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
      final settingsRepository = UserSettingsRepository(database: sharedDb);
      final sharedReportsRepository = SharedReportsRepository(
        database: sharedDb,
      );

      await settingsRepository.updateRole('PARENT');
      await settingsRepository.updateName('보호자');
      await sharedReportsRepository.importFromJson(
        source: 'resolroutine_report_20260221_M3.json',
        payloadJson: _sampleSharedReportJson(),
      );

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

      await _pumpUntilVisible(tester, find.textContaining('오답 1개'));
      await tester.tap(find.textContaining('오답 1개'));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('리포트 상세'));

      expect(find.textContaining('ID L-001'), findsNothing);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('ID L-001'), findsOneWidget);
    },
  );

  testWidgets('parent detail shows vocab lemma and unknown id fallback', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);
    final sharedReportsRepository = SharedReportsRepository(database: sharedDb);

    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');
    await sharedDb
        .into(sharedDb.vocabMaster)
        .insert(
          VocabMasterCompanion.insert(
            id: 'known_vocab_id',
            lemma: 'orchard',
            meaning: '과수원',
          ),
        );
    await sharedReportsRepository.importFromJson(
      source: 'resolroutine_report_20260222_M3.json',
      payloadJson: _sampleSharedReportWithVocabQuizJson(
        knownVocabId: 'known_vocab_id',
      ),
    );

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

    await _pumpUntilVisible(tester, find.text('리포트 가져오기'));
    await _pumpUntilVisible(tester, find.text('민수'));
    await tester.tap(find.text('민수'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('리포트 상세'));

    expect(find.text('orchard'), findsNothing);
    expect(find.text('missing_vocab_id'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('orchard'));

    expect(find.text('orchard'), findsOneWidget);
    expect(find.text('missing_vocab_id'), findsOneWidget);
  });

  testWidgets('parent detail shows deleted state after row removal', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);
    final sharedReportsRepository = SharedReportsRepository(database: sharedDb);

    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');
    final importedId = await sharedReportsRepository.importFromJson(
      source: 'resolroutine_report_20260221_M3.json',
      payloadJson: _sampleSharedReportJson(),
    );

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

    await _pumpUntilVisible(tester, find.textContaining('오답 1개'));
    await tester.tap(find.textContaining('오답 1개'));
    await tester.pumpAndSettle();
    await _pumpUntilVisible(tester, find.text('리포트 상세'));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ResolRoutineApp)),
    );
    await tester.runAsync(() async {
      await sharedReportsRepository.deleteById(importedId);
    });
    container.invalidate(sharedReportByIdProvider(importedId));
    container.invalidate(sharedReportSummariesProvider);
    await tester.pumpAndSettle();

    expect(find.text('삭제된 리포트입니다'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '목록으로'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '목록으로'));
    await tester.pumpAndSettle();

    expect(find.text('가정 리포트'), findsOneWidget);
    expect(find.text('아직 가져온 리포트가 없습니다.'), findsOneWidget);
  });

  testWidgets('parent home deletes imported report from list', (
    WidgetTester tester,
  ) async {
    final sharedDb = AppDatabase(executor: NativeDatabase.memory());
    final fakeSessionRepository = _FakeTodaySessionRepository(sharedDb);
    final fakeQuizRepository = _FakeTodayQuizRepository(sharedDb);
    final settingsRepository = UserSettingsRepository(database: sharedDb);
    final sharedReportsRepository = SharedReportsRepository(database: sharedDb);

    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('보호자');
    await sharedReportsRepository.importFromJson(
      source: 'resolroutine_report_20260221_M3.json',
      payloadJson: _sampleSharedReportJson(),
    );

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

    await _pumpUntilVisible(tester, find.text('리포트 가져오기'));
    await _pumpUntilVisible(tester, find.textContaining('오답 1개'));
    expect(find.textContaining('오답 1개'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('리포트 삭제'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text('아직 가져온 리포트가 없습니다.'), findsOneWidget);
    expect(find.textContaining('오답 1개'), findsNothing);

    final rows = await (sharedDb.select(sharedDb.sharedReports)).get();
    expect(rows, isEmpty);
  });

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

      await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 지훈! 👋'));
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

    await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 지훈! 👋'));
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

    await _pumpUntilVisible(tester, find.text('오늘도 화이팅, 민수! 👋'));
    await tester.tap(find.text('마이'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 루틴 완료'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
    expect(find.text('최근 7일 완료 일수'), findsOneWidget);
    expect(find.text('2일'), findsOneWidget);
    expect(find.text('총 시도'), findsOneWidget);
    expect(find.text('3회'), findsOneWidget);
    expect(find.text('총 오답'), findsOneWidget);
    expect(find.text('2회'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('학습 리포트'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('학습 리포트'), findsOneWidget);
    expect(find.text('이번주 외운 단어'), findsNothing);

    await tester.tap(find.text('학습 리포트'));
    await tester.pumpAndSettle();
    expect(find.text('리포트'), findsOneWidget);
    expect(find.text('JSON 리포트 공유'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
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
    expect(find.text('3일'), findsOneWidget);
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

class _FakeTodaySessionRepository extends TodaySessionRepository {
  _FakeTodaySessionRepository(AppDatabase database) : super(database: database);

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) async {
    return DailySessionBundle(
      sessionId: 1,
      dayKey: '20260219',
      track: track,
      plannedItems: 6,
      completedItems: 0,
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

String _sampleSharedReportJson() {
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'generatedAt': '2026-02-21T10:00:00.000Z',
    'student': <String, Object?>{
      'role': 'STUDENT',
      'displayName': '민수',
      'track': 'M3',
    },
    'days': <Object?>[
      <String, Object?>{
        'dayKey': '20260221',
        'track': 'M3',
        'solvedCount': 2,
        'wrongCount': 1,
        'listeningCorrect': 1,
        'readingCorrect': 0,
        'wrongReasonCounts': <String, Object?>{'VOCAB': 1},
        'questions': <Object?>[
          <String, Object?>{
            'questionId': 'L-001',
            'skill': 'LISTENING',
            'typeTag': 'L1',
            'isCorrect': true,
          },
          <String, Object?>{
            'questionId': 'R-001',
            'skill': 'READING',
            'typeTag': 'R1',
            'isCorrect': false,
            'wrongReasonTag': 'VOCAB',
          },
        ],
      },
    ],
  });
}

String _sampleSharedReportWithVocabQuizJson({required String knownVocabId}) {
  return jsonEncode(<String, Object?>{
    'schemaVersion': 2,
    'generatedAt': '2026-02-22T10:00:00.000Z',
    'student': <String, Object?>{
      'role': 'STUDENT',
      'displayName': '민수',
      'track': 'M3',
    },
    'days': <Object?>[
      <String, Object?>{
        'dayKey': '20260222',
        'track': 'M3',
        'solvedCount': 0,
        'wrongCount': 0,
        'listeningCorrect': 0,
        'readingCorrect': 0,
        'wrongReasonCounts': <String, Object?>{},
        'questions': <Object?>[],
        'vocabQuiz': <String, Object?>{
          'totalCount': 20,
          'correctCount': 18,
          'wrongVocabIds': <Object?>[knownVocabId, 'missing_vocab_id'],
        },
      },
    ],
  });
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
