import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';
import 'package:resol_routine/features/vocab/application/vocab_providers.dart';
import 'package:resol_routine/features/vocab/data/vocab_quiz_results_repository.dart';
import 'package:resol_routine/features/vocab/presentation/today_vocab_quiz_screen.dart';

void main() {
  testWidgets(
    'loads custom bookmarked vocab in quiz and persists completion once',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final spyResultsRepository = _SpyVocabQuizResultsRepository(
        database: database,
      );
      var cumulativeBuildCount = 0;
      var todayBuildCount = 0;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          vocabQuizResultsRepositoryProvider.overrideWithValue(
            spyResultsRepository,
          ),
          studentCumulativeReportProvider.overrideWith((ref, track) async {
            cumulativeBuildCount += 1;
            return _fakeReportSchema();
          }),
          studentTodayReportProvider.overrideWith((ref, track) async {
            todayBuildCount += 1;
            return null;
          }),
        ],
      );

      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      await _seedQuizPool(database);
      final cumulativeSubscription = container.listen(
        studentCumulativeReportProvider('M3'),
        (_, _) {},
        fireImmediately: true,
      );
      final todaySubscription = container.listen(
        studentTodayReportProvider('M3'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(cumulativeSubscription.close);
      addTearDown(todaySubscription.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TodayVocabQuizScreen()),
        ),
      );

      await _pumpUntilVisible(tester, find.text('priority_custom_lemma'));
      final cumulativeBefore = cumulativeBuildCount;
      final todayBefore = todayBuildCount;

      for (var iteration = 0; iteration < 20; iteration++) {
        await tester.scrollUntilVisible(
          find.textContaining('A. '),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.textContaining('A. ').first);
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('제출하기'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('제출하기'));
        await tester.pumpAndSettle();
        final nextLabel = iteration == 19 ? '완료' : '다음';
        await tester.scrollUntilVisible(
          find.text(nextLabel),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text(nextLabel));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('오늘의 단어 시험 완료'), findsOneWidget);
      expect(spyResultsRepository.upsertCallCount, 1);

      final rows = await (database.select(database.vocabQuizResults)).get();
      expect(rows, hasLength(1));
      expect(rows.single.totalCount, 20);
      expect(cumulativeBuildCount, greaterThan(cumulativeBefore));
      expect(todayBuildCount, greaterThan(todayBefore));
    },
  );
}

Future<void> _seedQuizPool(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.vocabMaster, <VocabMasterCompanion>[
      for (var i = 0; i < 24; i++)
        VocabMasterCompanion.insert(
          id: 'seed_vocab_$i',
          lemma: 'seed_lemma_$i',
          meaning: 'seed_meaning_$i',
        ),
      VocabMasterCompanion.insert(
        id: 'user_priority_custom',
        lemma: 'priority_custom_lemma',
        meaning: 'priority_custom_meaning',
      ),
    ]);
    batch.insert(
      database.vocabUser,
      VocabUserCompanion.insert(
        vocabId: 'user_priority_custom',
        isBookmarked: const Value(true),
      ),
    );
  });
}

ReportSchema _fakeReportSchema() {
  return ReportSchema.v3(
    generatedAt: DateTime.utc(2026, 2, 22, 0, 0),
    appVersion: 'test',
    student: const ReportStudent(),
    days: const <ReportDay>[],
    vocabBookmarks: const ReportVocabBookmarks(bookmarkedVocabIds: <String>[]),
  );
}

class _SpyVocabQuizResultsRepository extends VocabQuizResultsRepository {
  _SpyVocabQuizResultsRepository({required super.database});

  int upsertCallCount = 0;

  @override
  Future<void> upsertDailyResult({
    required String dayKey,
    required String track,
    required int totalCount,
    required int correctCount,
    required List<String> wrongVocabIds,
  }) async {
    upsertCallCount += 1;
    await super.upsertDailyResult(
      dayKey: dayKey,
      track: track,
      totalCount: totalCount,
      correctCount: correctCount,
      wrongVocabIds: wrongVocabIds,
    );
  }
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 300,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Did not find expected widget after ${maxPumps * 30}ms.');
}
