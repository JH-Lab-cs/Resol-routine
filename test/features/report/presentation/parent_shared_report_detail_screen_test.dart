import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
import 'package:resol_routine/features/report/presentation/parent_shared_report_detail_screen.dart';

void main() {
  testWidgets(
    'shows custom vocab lemma in parent detail without local vocab_master row',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final sharedReportsRepository = SharedReportsRepository(
        database: database,
      );
      addTearDown(database.close);

      final report = ReportSchema.v4(
        generatedAt: DateTime.utc(2026, 2, 21, 12, 0),
        appVersion: '1.0.0+1',
        student: const ReportStudent(
          role: 'STUDENT',
          displayName: '민수',
          track: Track.m3,
        ),
        days: const <ReportDay>[
          ReportDay(
            dayKey: '20260221',
            track: Track.m3,
            solvedCount: 0,
            wrongCount: 0,
            listeningCorrect: 0,
            readingCorrect: 0,
            wrongReasonCounts: <WrongReasonTag, int>{},
            questions: <ReportQuestionResult>[],
            vocabQuiz: ReportVocabQuizSummary(
              totalCount: 20,
              correctCount: 19,
              wrongVocabIds: <String>['user_custom_vocab_1'],
            ),
          ),
        ],
        vocabBookmarks: const ReportVocabBookmarks(
          bookmarkedVocabIds: <String>['user_custom_vocab_1'],
        ),
        customVocab: const ReportCustomVocab(
          lemmasById: <String, String>{'user_custom_vocab_1': 'glimmer'},
        ),
      );
      final sharedReportId = await sharedReportsRepository.importFromJson(
        source: 'resolroutine_report_20260221_M3.json',
        payloadJson: report.encodeCompact(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: ParentSharedReportDetailScreen(
              sharedReportId: sharedReportId,
            ),
          ),
        ),
      );

      await _pumpUntilVisible(tester, find.text('리포트 상세'));
      expect(find.text('user_custom_vocab_1'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('report-day-toggle-20260221-M3')),
      );
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('glimmer'));
      expect(find.text('user_custom_vocab_1'), findsNothing);

      await tester.tap(find.text('북마크 단어장'));
      await tester.pumpAndSettle();
      expect(find.text('glimmer'), findsAtLeastNWidgets(1));
      expect(find.text('user_custom_vocab_1'), findsNothing);
    },
  );
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
