import 'dart:io';

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
import 'package:resol_routine/features/wrong_notes/presentation/wrong_notes_screen.dart';

void main() {
  testWidgets('opens mock exam result screen from wrong note result action', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    late int attemptId;
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

      final attempts =
          await (database.select(database.attempts)
                ..where((tbl) => tbl.mockSessionId.equals(session.sessionId))
                ..limit(1))
              .getSingle();
      attemptId = attempts.id;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: WrongNotesScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('주간 모의고사 ·'), findsOneWidget);

    final resultButton = find.byKey(
      ValueKey<String>('wrong-note-open-result-$attemptId'),
    );
    expect(resultButton, findsOneWidget);

    await tester.tap(resultButton);
    await tester.pumpAndSettle();

    expect(find.text('주간 모의고사 결과'), findsAtLeastNWidgets(1));
  });
}
