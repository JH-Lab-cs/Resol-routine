import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';
import 'package:resol_routine/features/wrong_notes/presentation/wrong_review_screen.dart';

void main() {
  testWidgets('opens retry screen from wrong review session', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await tester.runAsync(() async {
      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      final question =
          await (database.select(database.questions)
                ..where((tbl) => tbl.track.equals('M3'))
                ..limit(1))
              .getSingle();
      final sessionId = await database
          .into(database.dailySessions)
          .insert(
            DailySessionsCompanion.insert(
              dayKey: 20260303,
              track: const Value('M3'),
              plannedItems: const Value(6),
              completedItems: const Value(1),
            ),
          );

      await database
          .into(database.attempts)
          .insert(
            AttemptsCompanion.insert(
              questionId: question.id,
              sessionId: Value(sessionId),
              mockSessionId: const Value(null),
              userAnswerJson: '{"selectedAnswer":"B","wrongReasonTag":"VOCAB"}',
              isCorrect: false,
              attemptedAt: Value(DateTime.utc(2026, 3, 3, 12, 0)),
            ),
          );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: WrongReviewScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('wrong-review-open-2026-03-03')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('오답 복습'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('다시 풀기').first);
    await tester.pumpAndSettle();
    expect(find.text('다시 풀기'), findsAtLeastNWidgets(1));
  });

  testWidgets('opens mock exam result screen from wrong note result action', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await tester.runAsync(() async {
      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      final sessionRepository = MockExamSessionRepository(database: database);
      final attemptRepository = MockExamAttemptRepository(database: database);
      final session = await sessionRepository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: const MockExamQuestionPlan(listeningCount: 1, readingCount: 0),
        nowLocal: DateTime(2026, 2, 24, 9, 0),
      );

      await attemptRepository.saveAttemptIdempotent(
        mockSessionId: session.sessionId,
        questionId: session.items.first.questionId,
        selectedAnswer: 'B',
        isCorrect: false,
        wrongReasonTag: WrongReasonTag.vocab,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: WrongReviewScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();

    final resultButton = find.byTooltip('결과 보기');
    expect(resultButton, findsOneWidget);
    await tester.tap(resultButton);
    await tester.pumpAndSettle();

    expect(find.text('주간 모의고사 결과'), findsAtLeastNWidgets(1));
  });
}
