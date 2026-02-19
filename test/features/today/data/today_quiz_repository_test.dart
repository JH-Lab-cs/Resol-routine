import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/today/data/today_quiz_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';

void main() {
  group('TodayQuizRepository', () {
    late AppDatabase database;
    late TodayQuizRepository quizRepository;
    late TodaySessionRepository sessionRepository;
    late String starterPackJson;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();

      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      quizRepository = TodayQuizRepository(database: database);
      sessionRepository = TodaySessionRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('wrong attempt cannot be saved without wrongReasonTag', () async {
      final session = await sessionRepository.getOrCreateSession(
        track: 'M3',
        nowLocal: DateTime(2026, 2, 19, 9, 0),
      );
      final questionId = session.items.first.questionId;

      await expectLater(
        quizRepository.saveAttempt(
          sessionId: session.sessionId,
          questionId: questionId,
          selectedAnswer: 'A',
          isCorrect: false,
        ),
        throwsA(isA<StateError>()),
      );

      final attempts = await database.select(database.attempts).get();
      expect(attempts, isEmpty);
    });

    test(
      'completedItems remains 1 when same question is saved twice',
      () async {
        final session = await sessionRepository.getOrCreateSession(
          track: 'M3',
          nowLocal: DateTime(2026, 2, 19, 10, 0),
        );
        final questionId = session.items.first.questionId;

        await quizRepository.saveAttemptIdempotent(
          sessionId: session.sessionId,
          questionId: questionId,
          selectedAnswer: 'A',
          isCorrect: false,
          wrongReasonTag: 'VOCAB',
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: session.sessionId,
          questionId: questionId,
          selectedAnswer: 'B',
          isCorrect: true,
        );

        final attempts =
            await (database.select(database.attempts)..where(
                  (tbl) =>
                      tbl.sessionId.equals(session.sessionId) &
                      tbl.questionId.equals(questionId),
                ))
                .get();
        expect(attempts, hasLength(1));

        final dailySession = await (database.select(
          database.dailySessions,
        )..where((tbl) => tbl.id.equals(session.sessionId))).getSingle();
        expect(dailySession.completedItems, 1);
      },
    );

    test(
      'findFirstUnansweredOrderIndex returns next unresolved position',
      () async {
        final session = await sessionRepository.getOrCreateSession(
          track: 'H1',
          nowLocal: DateTime(2026, 2, 19, 11, 0),
        );

        await quizRepository.saveAttemptIdempotent(
          sessionId: session.sessionId,
          questionId: session.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await quizRepository.saveAttemptIdempotent(
          sessionId: session.sessionId,
          questionId: session.items[1].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        final firstUnanswered = await quizRepository
            .findFirstUnansweredOrderIndex(sessionId: session.sessionId);
        expect(firstUnanswered, 2);
      },
    );

    test(
      'deleteTodaySession removes session, items, and attempts together',
      () async {
        final nowLocal = DateTime(2026, 2, 19, 12, 0);
        final session = await sessionRepository.getOrCreateSession(
          track: 'H2',
          nowLocal: nowLocal,
        );

        await quizRepository.saveAttemptIdempotent(
          sessionId: session.sessionId,
          questionId: session.items.first.questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        await quizRepository.deleteTodaySession(
          track: 'H2',
          nowLocal: nowLocal,
        );

        final sessionRows = await (database.select(
          database.dailySessions,
        )..where((tbl) => tbl.id.equals(session.sessionId))).get();
        expect(sessionRows, isEmpty);

        final itemCountRow = await database
            .customSelect(
              'SELECT COUNT(*) AS cnt FROM daily_session_items WHERE session_id = ?',
              variables: [Variable<int>(session.sessionId)],
              readsFrom: {database.dailySessionItems},
            )
            .getSingle();
        expect(itemCountRow.read<int>('cnt'), 0);

        final attemptCountRow = await database
            .customSelect(
              'SELECT COUNT(*) AS cnt FROM attempts WHERE session_id = ?',
              variables: [Variable<int>(session.sessionId)],
              readsFrom: {database.attempts},
            )
            .getSingle();
        expect(attemptCountRow.read<int>('cnt'), 0);
      },
    );
  });
}
