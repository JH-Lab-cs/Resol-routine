import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/core/ui/app_copy_ko.dart';
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

      final report = ReportSchema.v5(
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
            solvedCount: 1,
            wrongCount: 1,
            listeningCorrect: 0,
            readingCorrect: 0,
            wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.vocab: 1},
            questions: <ReportQuestionResult>[
              ReportQuestionResult(
                questionId: 'Q-20260221-L1',
                skill: Skill.listening,
                typeTag: 'L1',
                isCorrect: false,
                wrongReasonTag: WrongReasonTag.vocab,
              ),
            ],
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
        mockExams: ReportMockExams(
          weekly: <ReportMockExamSummary>[
            ReportMockExamSummary(
              periodKey: '2026W08',
              track: Track.m3,
              totalCount: 20,
              listeningCorrect: 7,
              readingCorrect: 8,
              correctCount: 15,
              wrongCount: 5,
              completedAt: DateTime.utc(2026, 2, 21, 10, 30),
            ),
          ],
          monthly: const <ReportMockExamSummary>[],
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
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey<String>('report-day-toggle-20260221-M3')),
      );

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

      await tester.tap(find.text('모의고사 요약'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2026W08'), findsOneWidget);
      expect(find.textContaining('정답 15/20 · 75%'), findsOneWidget);
    },
  );

  testWidgets(
    'applies date and question filters and keeps only matching days',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final sharedReportsRepository = SharedReportsRepository(
        database: database,
      );
      addTearDown(database.close);

      final report = _buildFilterReport();
      final sharedReportId = await sharedReportsRepository.importFromJson(
        source: 'resolroutine_report_20260228_M3.json',
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
      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey<String>('report-day-toggle-20260221-M3')),
      );
      expect(
        find.byKey(const ValueKey<String>('report-day-toggle-20260221-M3')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('filter-range-last7')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('report-day-toggle-20260221-M3')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('filter-wrong-VOCAB')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('filter-typeTag')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('filter-typeTag')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('typeTag-option-L_GIST')),
      );
      await tester.pumpAndSettle();

      await _scrollUntilVisible(
        tester,
        find.byKey(const ValueKey<String>('report-day-toggle-20260228-M3')),
      );
      expect(
        find.byKey(const ValueKey<String>('report-day-toggle-20260228-M3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('report-day-toggle-20260226-M3')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('report-day-toggle-20260228-M3')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ID Q-20260228-L1'), findsOneWidget);
      expect(find.textContaining('ID Q-20260228-R1'), findsNothing);
    },
  );

  testWidgets('shows empty state when combined filters have no results', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final sharedReportsRepository = SharedReportsRepository(database: database);
    addTearDown(database.close);

    final report = _buildFilterReport();
    final sharedReportId = await sharedReportsRepository.importFromJson(
      source: 'resolroutine_report_20260228_M3.json',
      payloadJson: report.encodeCompact(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: ParentSharedReportDetailScreen(sharedReportId: sharedReportId),
        ),
      ),
    );

    await _pumpUntilVisible(tester, find.text('리포트 상세'));
    await _scrollUntilVisible(
      tester,
      find.byKey(const ValueKey<String>('filter-range-last7')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('filter-range-last7')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('filter-wrong-TIME')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('filter-wrong-TIME')));
    await tester.pumpAndSettle();

    expect(find.text(AppCopyKo.emptyFilteredDays), findsOneWidget);
  });
}

ReportSchema _buildFilterReport() {
  return ReportSchema.v4(
    generatedAt: DateTime.utc(2026, 2, 28, 12, 0),
    appVersion: '1.0.0+1',
    student: const ReportStudent(
      role: 'STUDENT',
      displayName: '민수',
      track: Track.m3,
    ),
    days: const <ReportDay>[
      ReportDay(
        dayKey: '20260228',
        track: Track.m3,
        solvedCount: 2,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 1,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.vocab: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260228-L1',
            skill: Skill.listening,
            typeTag: 'L1',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.vocab,
          ),
          ReportQuestionResult(
            questionId: 'Q-20260228-R1',
            skill: Skill.reading,
            typeTag: 'R1',
            isCorrect: true,
            wrongReasonTag: null,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260227',
        track: Track.m3,
        solvedCount: 2,
        wrongCount: 2,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{
          WrongReasonTag.evidence: 1,
          WrongReasonTag.careless: 1,
        },
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260227-L2',
            skill: Skill.listening,
            typeTag: 'L2',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.evidence,
          ),
          ReportQuestionResult(
            questionId: 'Q-20260227-R2',
            skill: Skill.reading,
            typeTag: 'R2',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.careless,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260226',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.inference: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260226-R1',
            skill: Skill.reading,
            typeTag: 'R1',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.inference,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260225',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 0,
        listeningCorrect: 1,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260225-L3',
            skill: Skill.listening,
            typeTag: 'L3',
            isCorrect: true,
            wrongReasonTag: null,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260224',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.evidence: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260224-R3',
            skill: Skill.reading,
            typeTag: 'R3',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.evidence,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260223',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.careless: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260223-L1',
            skill: Skill.listening,
            typeTag: 'L1',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.careless,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260222',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 0,
        listeningCorrect: 0,
        readingCorrect: 1,
        wrongReasonCounts: <WrongReasonTag, int>{},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260222-R2',
            skill: Skill.reading,
            typeTag: 'R2',
            isCorrect: true,
            wrongReasonTag: null,
          ),
        ],
      ),
      ReportDay(
        dayKey: '20260221',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.vocab: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260221-L1',
            skill: Skill.listening,
            typeTag: 'L1',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.vocab,
          ),
        ],
      ),
    ],
    vocabBookmarks: const ReportVocabBookmarks(bookmarkedVocabIds: <String>[]),
    customVocab: const ReportCustomVocab(lemmasById: <String, String>{}),
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

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
