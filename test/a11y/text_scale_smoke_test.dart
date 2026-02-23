import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/home/presentation/home_screen.dart';
import 'package:resol_routine/features/my/presentation/my_screen.dart';
import 'package:resol_routine/features/my/presentation/my_settings_screen.dart';
import 'package:resol_routine/features/report/application/report_providers.dart';
import 'package:resol_routine/features/report/data/models/report_schema_v1.dart';
import 'package:resol_routine/features/report/data/shared_reports_repository.dart';
import 'package:resol_routine/features/report/presentation/parent_shared_report_detail_screen.dart';
import 'package:resol_routine/features/report/presentation/student_report_screen.dart';
import 'package:resol_routine/features/root/presentation/root_shell.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';
import 'package:resol_routine/features/today/application/today_quiz_providers.dart';
import 'package:resol_routine/features/today/application/today_session_providers.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';
import 'package:resol_routine/features/today/presentation/quiz_flow_screen.dart';
import 'package:resol_routine/features/vocab/presentation/vocab_screen.dart';
import 'package:resol_routine/features/wrong_notes/presentation/wrong_notes_screen.dart';

void main() {
  testWidgets('root shell (student/parent) remains stable at text scale 2.0', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    final settingsRepository = UserSettingsRepository(database: database);
    await settingsRepository.updateRole('STUDENT');
    await settingsRepository.updateName('학생');
    await settingsRepository.updateTrack('M3');

    await tester.pumpWidget(
      _withTextScale(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: RootShell()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await settingsRepository.updateRole('PARENT');
    await settingsRepository.updateName('부모');
    await tester.pumpWidget(
      _withTextScale(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: RootShell()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home/vocab/wrong-notes/my/settings remain stable at text scale 2.0',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final settingsRepository = UserSettingsRepository(database: database);
      await settingsRepository.updateRole('STUDENT');
      await settingsRepository.updateName('학생');
      await settingsRepository.updateTrack('M3');

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              home: HomeScreen(
                onOpenQuiz: () {},
                onOpenWeeklyMockExam: () {},
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
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const MaterialApp(home: Scaffold(body: VocabScreen())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const MaterialApp(home: Scaffold(body: WrongNotesScreen())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const MaterialApp(home: Scaffold(body: MyScreen())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const MaterialApp(home: MySettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quiz flow empty/progress states remain stable at text scale 2.0',
    (WidgetTester tester) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final emptySessionRepository = _FakeTodaySessionRepository(
        database: database,
        bundle: const DailySessionBundle(
          sessionId: 1,
          dayKey: '20260223',
          track: 'M3',
          plannedItems: 6,
          completedItems: 0,
          items: <DailySessionItemBundle>[
            DailySessionItemBundle(
              orderIndex: 0,
              questionId: 'Q-EMPTY',
              skill: 'LISTENING',
            ),
          ],
        ),
      );
      final emptyQuizRepository = _FakeTodayQuizRepository(
        database: database,
        questions: const <QuizQuestionDetail>[],
      );

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              todaySessionRepositoryProvider.overrideWithValue(
                emptySessionRepository,
              ),
              todayQuizRepositoryProvider.overrideWithValue(
                emptyQuizRepository,
              ),
            ],
            child: const MaterialApp(home: QuizFlowScreen(track: 'M3')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final progressSessionRepository = _FakeTodaySessionRepository(
        database: database,
        bundle: const DailySessionBundle(
          sessionId: 2,
          dayKey: '20260223',
          track: 'M3',
          plannedItems: 6,
          completedItems: 0,
          items: <DailySessionItemBundle>[
            DailySessionItemBundle(
              orderIndex: 0,
              questionId: 'Q-PROGRESS',
              skill: 'LISTENING',
            ),
          ],
        ),
      );
      final progressQuizRepository = _FakeTodayQuizRepository(
        database: database,
        questions: const <QuizQuestionDetail>[
          QuizQuestionDetail(
            orderIndex: 0,
            questionId: 'Q-PROGRESS',
            skill: Skill.listening,
            typeTag: 'L1',
            track: Track.m3,
            prompt: 'What should the student choose?',
            options: OptionMap(a: 'A1', b: 'B1', c: 'C1', d: 'D1', e: 'E1'),
            answerKey: 'A',
            whyCorrectKo: '근거가 일치합니다.',
            whyWrongKo: OptionMap(a: '정답', b: '오답', c: '오답', d: '오답', e: '오답'),
            evidenceSentenceIds: <String>['S1'],
            sourceLines: <SourceLine>[
              SourceLine(
                sentenceIds: <String>['S1'],
                text: 'Sample listening line',
                index: 0,
                speaker: 'S1',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        _withTextScale(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(database),
              todaySessionRepositoryProvider.overrideWithValue(
                progressSessionRepository,
              ),
              todayQuizRepositoryProvider.overrideWithValue(
                progressQuizRepository,
              ),
            ],
            child: const MaterialApp(home: QuizFlowScreen(track: 'M3')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student report screen remains stable at text scale 2.0', (
    WidgetTester tester,
  ) async {
    final report = _buildSmokeReport();

    await tester.pumpWidget(
      _withTextScale(
        ProviderScope(
          overrides: [
            studentCumulativeReportProvider.overrideWith(
              (ref, track) async => report,
            ),
          ],
          child: const MaterialApp(home: StudentReportScreen(track: 'M3')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent shared report detail remains stable at text scale 2.0', (
    WidgetTester tester,
  ) async {
    final report = _buildSmokeReport();
    final record = SharedReportRecord(
      id: 1,
      source: 'resolroutine_report_20260223_M3.json',
      payloadJson: report.encodeCompact(),
      createdAt: DateTime.utc(2026, 2, 23, 12, 0),
      report: report,
    );

    await tester.pumpWidget(
      _withTextScale(
        ProviderScope(
          overrides: [
            sharedReportByIdProvider.overrideWith((ref, id) async => record),
          ],
          child: const MaterialApp(
            home: ParentSharedReportDetailScreen(sharedReportId: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

ReportSchema _buildSmokeReport() {
  return ReportSchema.v4(
    generatedAt: DateTime.utc(2026, 2, 23, 12, 0),
    appVersion: '1.0.0+1',
    student: const ReportStudent(
      role: 'STUDENT',
      displayName: '민수',
      track: Track.m3,
    ),
    days: const <ReportDay>[
      ReportDay(
        dayKey: '20260223',
        track: Track.m3,
        solvedCount: 1,
        wrongCount: 1,
        listeningCorrect: 0,
        readingCorrect: 0,
        wrongReasonCounts: <WrongReasonTag, int>{WrongReasonTag.vocab: 1},
        questions: <ReportQuestionResult>[
          ReportQuestionResult(
            questionId: 'Q-20260223-L1',
            skill: Skill.listening,
            typeTag: 'L1',
            isCorrect: false,
            wrongReasonTag: WrongReasonTag.vocab,
          ),
        ],
        vocabQuiz: ReportVocabQuizSummary(
          totalCount: 20,
          correctCount: 18,
          wrongVocabIds: <String>['user_vocab_1'],
        ),
      ),
    ],
    vocabBookmarks: const ReportVocabBookmarks(
      bookmarkedVocabIds: <String>['user_vocab_1'],
    ),
    customVocab: const ReportCustomVocab(
      lemmasById: <String, String>{'user_vocab_1': 'glimmer'},
    ),
  );
}

Widget _withTextScale(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
    child: child,
  );
}

class _FakeTodaySessionRepository extends TodaySessionRepository {
  _FakeTodaySessionRepository({required super.database, required this.bundle})
    : super();

  final DailySessionBundle bundle;

  @override
  Future<DailySessionBundle> getOrCreateSession({
    required String track,
    DateTime? nowLocal,
  }) async {
    return bundle;
  }
}

class _FakeTodayQuizRepository extends TodayQuizRepository {
  _FakeTodayQuizRepository({required super.database, required this.questions})
    : super();

  final List<QuizQuestionDetail> questions;

  @override
  Future<List<QuizQuestionDetail>> loadSessionQuestions(int sessionId) async {
    return questions;
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

  @override
  Future<SessionCompletionReport> loadSessionCompletionReport(
    int sessionId,
  ) async {
    return const SessionCompletionReport(
      listeningCorrectCount: 0,
      readingCorrectCount: 0,
      wrongCount: 0,
      topWrongReasonTag: null,
    );
  }
}
