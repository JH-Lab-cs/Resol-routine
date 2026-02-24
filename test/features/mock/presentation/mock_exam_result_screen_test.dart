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
import 'package:resol_routine/features/mock_exam/presentation/mock_exam_result_screen.dart';

void main() {
  group('MockExamResultScreen', () {
    testWidgets('renders summary and filters wrong items for review', (
      WidgetTester tester,
    ) async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      await _seedMockExamQuestionPool(
        database,
        track: 'M3',
        listeningCount: 8,
        readingCount: 8,
      );

      final nowLocal = DateTime.utc(2026, 3, 1, 2, 0);
      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);
      final session = await sessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
        nowLocal: nowLocal,
      );

      final correctQuestionIds = <String>[
        session.items[0].questionId,
        session.items[3].questionId,
      ];
      final wrongQuestionIds = <String>[
        session.items[1].questionId,
        session.items[2].questionId,
      ];

      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: correctQuestionIds[0],
        selectedAnswer: 'A',
        isCorrect: true,
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: wrongQuestionIds[0],
        selectedAnswer: 'B',
        isCorrect: false,
        wrongReasonTag: WrongReasonTag.vocab,
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: wrongQuestionIds[1],
        selectedAnswer: 'C',
        isCorrect: false,
        wrongReasonTag: WrongReasonTag.evidence,
      );
      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: correctQuestionIds[1],
        selectedAnswer: 'A',
        isCorrect: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            home: MockExamResultScreen(
              mockSessionId: session.sessionId,
              examTitle: '주간 모의고사',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('정답 2/4 · 오답 2/4'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('mock-result-only-wrong-toggle')),
        300,
        scrollable: scrollable,
      );

      expect(
        find.byKey(const ValueKey<String>('mock-result-only-wrong-toggle')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text(correctQuestionIds[0]),
        300,
        scrollable: scrollable,
      );
      expect(find.text(correctQuestionIds[0]), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(wrongQuestionIds[0]),
        300,
        scrollable: scrollable,
      );
      expect(find.text(wrongQuestionIds[0]), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('mock-result-only-wrong-toggle')),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(wrongQuestionIds[0]),
        300,
        scrollable: scrollable,
      );

      expect(find.text(wrongQuestionIds[0]), findsOneWidget);

      await tester.tap(find.text(wrongQuestionIds[0]));
      await tester.pumpAndSettle();

      expect(find.text('오답 상세'), findsOneWidget);
    });
  });
}

Future<void> _seedMockExamQuestionPool(
  AppDatabase database, {
  required String track,
  required int listeningCount,
  required int readingCount,
}) async {
  final packId = 'result_pack_$track';
  final scriptId = 'result_script_$track';
  final passageId = 'result_passage_$track';
  const listeningSentenceId = 'ls-1';
  const readingSentenceId = 'rs-1';

  await database
      .into(database.contentPacks)
      .insert(
        ContentPacksCompanion.insert(
          id: packId,
          version: 1,
          locale: 'en-US',
          title: 'Result Pack $track',
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
