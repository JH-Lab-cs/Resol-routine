import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/ui/app_copy_ko.dart';
import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/mock_exam/presentation/mock_exam_history_screen.dart';

void main() {
  group('MockExamHistoryScreen', () {
    testWidgets('shows empty state and supports tab switching', (
      WidgetTester tester,
    ) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: MockExamHistoryScreen(track: 'M3')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppCopyKo.emptyMockHistory), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mock-history-tab-monthly')));
      await tester.pumpAndSettle();
      expect(find.text(AppCopyKo.emptyMockHistory), findsOneWidget);
    });

    testWidgets('renders session history and opens result screen on tap', (
      WidgetTester tester,
    ) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      await _seedMockExamQuestionPool(
        database,
        track: 'M3',
        listeningCount: 20,
        readingCount: 30,
      );

      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);

      final weeklySession = await sessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
        nowLocal: DateTime.utc(2026, 3, 1, 9, 0),
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: weeklySession.sessionId,
        questionId: weeklySession.items[0].questionId,
        selectedAnswer: 'A',
        isCorrect: true,
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: weeklySession.sessionId,
        questionId: weeklySession.items[1].questionId,
        selectedAnswer: 'B',
        isCorrect: false,
        wrongReasonTag: WrongReasonTag.vocab,
      );

      await sessionRepository.getOrCreateSession(
        type: MockExamType.monthly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
        nowLocal: DateTime.utc(2026, 3, 1, 9, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: MockExamHistoryScreen(track: 'M3')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('주간 모의고사'), findsOneWidget);
      expect(find.textContaining('정답 1/4 · 오답 1'), findsOneWidget);

      await tester.tap(find.textContaining('주간 모의고사'));
      await tester.pumpAndSettle();
      expect(find.text('주간 모의고사 결과'), findsAtLeastNWidgets(1));

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mock-history-tab-monthly')));
      await tester.pumpAndSettle();
      expect(find.textContaining('월간 모의고사'), findsOneWidget);
    });

    testWidgets('deletes history item after confirmation and shows snackbar', (
      WidgetTester tester,
    ) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      await _seedMockExamQuestionPool(
        database,
        track: 'M3',
        listeningCount: 20,
        readingCount: 30,
      );

      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);
      final session = await sessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
        nowLocal: DateTime.utc(2026, 3, 8, 9, 0),
      );
      for (var i = 0; i < session.items.length; i++) {
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: session.sessionId,
          questionId: session.items[i].questionId,
          selectedAnswer: i == 0 ? 'B' : 'A',
          isCorrect: i != 0,
          wrongReasonTag: i == 0 ? WrongReasonTag.vocab : null,
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: MockExamHistoryScreen(track: 'M3')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey<String>('mock-history-item-${session.sessionId}')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('mock-history-menu-${session.sessionId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('mock-history-delete-${session.sessionId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('기록 삭제'), findsOneWidget);
      await tester.tap(find.text(AppCopyKo.mockHistoryDeleteConfirm));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey<String>('mock-history-item-${session.sessionId}')),
        findsNothing,
      );
      expect(find.text(AppCopyKo.mockHistoryDeleteSuccess), findsOneWidget);
    });
  });
}

Future<void> _seedMockExamQuestionPool(
  AppDatabase database, {
  required String track,
  required int listeningCount,
  required int readingCount,
}) async {
  final packId = 'history_mock_pack_$track';
  final scriptId = 'history_mock_script_$track';
  final passageId = 'history_mock_passage_$track';
  const listeningSentenceId = 'ls-1';
  const readingSentenceId = 'rs-1';

  await database
      .into(database.contentPacks)
      .insert(
        ContentPacksCompanion.insert(
          id: packId,
          version: 1,
          locale: 'en-US',
          title: 'Mock Pack $track',
          checksum: 'sha256:$packId',
        ),
      );

  await database
      .into(database.scripts)
      .insert(
        ScriptsCompanion.insert(
          id: scriptId,
          packId: packId,
          sentencesJson: const <Sentence>[
            Sentence(id: listeningSentenceId, text: 'Listening source line'),
          ],
          turnsJson: const <Turn>[
            Turn(speaker: 'S1', sentenceIds: <String>[listeningSentenceId]),
          ],
          ttsPlanJson: const TtsPlan(
            repeatPolicy: <String, Object?>{
              'mode': 'per_turn',
              'repeatCount': 1,
            },
            pauseRangeMs: NumericRange(min: 300, max: 600),
            rateRange: NumericRange(min: 0.95, max: 1.05),
            pitchRange: NumericRange(min: 0.0, max: 1.2),
            voiceRoles: <String, String>{
              'S1': 'en-US-Standard-C',
              'S2': 'en-US-Standard-E',
              'N': 'en-US-Standard-A',
            },
          ),
          orderIndex: 0,
        ),
      );

  await database
      .into(database.passages)
      .insert(
        PassagesCompanion.insert(
          id: passageId,
          packId: packId,
          sentencesJson: const <Sentence>[
            Sentence(id: readingSentenceId, text: 'Reading source line'),
          ],
          orderIndex: 0,
        ),
      );

  const options = OptionMap(
    a: 'Alpha',
    b: 'Beta',
    c: 'Gamma',
    d: 'Delta',
    e: 'Epsilon',
  );
  const wrongMap = OptionMap(a: '정답', b: '오답', c: '오답', d: '오답', e: '오답');

  for (var i = 0; i < listeningCount; i++) {
    final questionId = 'Q_${track}_L_${i + 1}';
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: questionId,
            skill: Skill.listening.dbValue,
            typeTag: 'L${i + 1}',
            track: track,
            difficulty: 2,
            passageId: const Value(null),
            scriptId: Value(scriptId),
            prompt: 'Mock listening question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: i,
          ),
        );
    await database
        .into(database.explanations)
        .insert(
          ExplanationsCompanion.insert(
            id: 'EX_$questionId',
            questionId: questionId,
            evidenceSentenceIdsJson: const <String>[listeningSentenceId],
            whyCorrectKo: '근거가 일치합니다.',
            whyWrongKoJson: wrongMap,
          ),
        );
  }

  for (var i = 0; i < readingCount; i++) {
    final questionId = 'Q_${track}_R_${i + 1}';
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: questionId,
            skill: Skill.reading.dbValue,
            typeTag: 'R${i + 1}',
            track: track,
            difficulty: 2,
            passageId: Value(passageId),
            scriptId: const Value(null),
            prompt: 'Mock reading question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: listeningCount + i,
          ),
        );
    await database
        .into(database.explanations)
        .insert(
          ExplanationsCompanion.insert(
            id: 'EX_$questionId',
            questionId: questionId,
            evidenceSentenceIdsJson: const <String>[readingSentenceId],
            whyCorrectKo: '근거가 일치합니다.',
            whyWrongKoJson: wrongMap,
          ),
        );
  }
}
