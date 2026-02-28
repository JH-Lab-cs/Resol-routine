import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/mock_exam/presentation/monthly_mock_flow_screen.dart';
import 'package:resol_routine/features/root/presentation/root_shell.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

void main() {
  group('MonthlyMockFlowScreen', () {
    testWidgets('home monthly card opens monthly mock flow', (
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

      final settingsRepository = UserSettingsRepository(database: database);
      await settingsRepository.updateRole('STUDENT');
      await settingsRepository.updateName('테스터');
      await settingsRepository.updateTrack('M3');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: RootShell()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('반가워요, 테스터 학생! 👋'), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('월간 모의고사'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('월간 모의고사'), findsOneWidget);
      await tester.tap(find.text('월간 모의고사'));
      await tester.pumpAndSettle();

      expect(find.text('월간 모의고사'), findsAtLeastNWidgets(1));
      expect(find.text('시작하기'), findsOneWidget);

      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(find.text('문제 1 / 45'), findsOneWidget);
    });

    testWidgets('resumes from next unanswered question', (
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

      final nowLocal = DateTime.utc(2026, 3, 1, 2, 0);
      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);
      final session = await sessionRepository.getOrCreateSession(
        type: MockExamType.monthly,
        track: 'M3',
        plan: MockExamSessionRepository.monthlyDefaultPlan,
        nowLocal: nowLocal,
      );

      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: session.items.first.questionId,
        selectedAnswer: 'A',
        isCorrect: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: MonthlyMockFlowScreen(track: 'M3', nowLocal: nowLocal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('이어하기'), findsOneWidget);
      await tester.tap(find.text('이어하기'));
      await tester.pumpAndSettle();

      expect(find.text('월간 모의고사'), findsOneWidget);
      expect(find.text('문제 2 / 45'), findsOneWidget);
    });

    testWidgets('shows completion screen when all attempts already exist', (
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

      final nowLocal = DateTime.utc(2026, 3, 1, 2, 0);
      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);
      final session = await sessionRepository.getOrCreateSession(
        type: MockExamType.monthly,
        track: 'M3',
        plan: MockExamSessionRepository.monthlyDefaultPlan,
        nowLocal: nowLocal,
      );

      for (final item in session.items) {
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: session.sessionId,
          questionId: item.questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: MonthlyMockFlowScreen(track: 'M3', nowLocal: nowLocal),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('월간 모의고사 완료'), findsOneWidget);
      expect(find.textContaining('45문제'), findsOneWidget);
    });
  });
}

Future<void> _seedMockExamQuestionPool(
  AppDatabase database, {
  required String track,
  required int listeningCount,
  required int readingCount,
}) async {
  final packId = 'mock_pack_$track';
  final scriptId = 'mock_script_$track';
  final passageId = 'mock_passage_$track';
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
