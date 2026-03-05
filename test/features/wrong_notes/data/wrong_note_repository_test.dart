import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/today/data/attempt_payload.dart';
import 'package:resol_routine/features/wrong_notes/data/wrong_note_repository.dart';

void main() {
  group('WrongNoteRepository', () {
    late AppDatabase database;
    late WrongNoteRepository repository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());

      final starterPackJson = await File(
        'assets/content_packs/starter_pack.json',
      ).readAsString();
      final seeder = ContentPackSeeder(
        database: database,
        source: MemoryContentPackSource(starterPackJson),
      );
      await seeder.seedOnFirstLaunch();

      repository = WrongNoteRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'includes daily and mock wrong notes with deterministic ordering',
      () async {
        final questions =
            await (database.select(database.questions)
                  ..where((tbl) => tbl.track.equals('M3'))
                  ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)])
                  ..limit(4))
                .get();
        expect(questions.length, 4);

        final dailySessionId = await database
            .into(database.dailySessions)
            .insert(
              DailySessionsCompanion.insert(
                dayKey: 20260223,
                track: const Value('M3'),
                plannedItems: const Value(6),
                completedItems: const Value(2),
              ),
            );

        final dailyAttemptId1 = await database
            .into(database.attempts)
            .insert(
              AttemptsCompanion.insert(
                questionId: questions[0].id,
                sessionId: Value(dailySessionId),
                mockSessionId: const Value(null),
                userAnswerJson: AttemptPayload(
                  selectedAnswer: 'B',
                  wrongReasonTag: WrongReasonTag.vocab,
                ).encode(),
                isCorrect: false,
                attemptedAt: Value(DateTime.utc(2026, 2, 23, 1, 0)),
              ),
            );
        final dailyAttemptId2 = await database
            .into(database.attempts)
            .insert(
              AttemptsCompanion.insert(
                questionId: questions[1].id,
                sessionId: Value(dailySessionId),
                mockSessionId: const Value(null),
                userAnswerJson: AttemptPayload(
                  selectedAnswer: 'C',
                  wrongReasonTag: WrongReasonTag.evidence,
                ).encode(),
                isCorrect: false,
                attemptedAt: Value(DateTime.utc(2026, 2, 23, 2, 0)),
              ),
            );

        final weeklySessionId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.weekly.dbValue,
                periodKey: '2026W08',
                track: 'M3',
                plannedItems: 1,
                completedItems: const Value(1),
                completedAt: Value(DateTime.utc(2026, 2, 22, 8, 0)),
              ),
            );
        final weeklyAttemptId = await database
            .into(database.attempts)
            .insert(
              AttemptsCompanion.insert(
                questionId: questions[2].id,
                sessionId: const Value(null),
                mockSessionId: Value(weeklySessionId),
                userAnswerJson: AttemptPayload(
                  selectedAnswer: 'D',
                  wrongReasonTag: WrongReasonTag.inference,
                ).encode(),
                isCorrect: false,
                attemptedAt: Value(DateTime.utc(2026, 2, 22, 8, 5)),
              ),
            );

        final monthlySessionId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.monthly.dbValue,
                periodKey: '202602',
                track: 'M3',
                plannedItems: 1,
                completedItems: const Value(1),
                completedAt: Value(DateTime.utc(2026, 2, 24, 10, 0)),
              ),
            );
        final monthlyAttemptId = await database
            .into(database.attempts)
            .insert(
              AttemptsCompanion.insert(
                questionId: questions[3].id,
                sessionId: const Value(null),
                mockSessionId: Value(monthlySessionId),
                userAnswerJson: AttemptPayload(
                  selectedAnswer: 'E',
                  wrongReasonTag: WrongReasonTag.careless,
                ).encode(),
                isCorrect: false,
                attemptedAt: Value(DateTime.utc(2026, 2, 24, 10, 1)),
              ),
            );

        final items = await repository.listIncorrectAttempts();

        expect(
          items.map((item) => item.attemptId).toList(growable: false),
          <int>[
            monthlyAttemptId,
            dailyAttemptId2,
            dailyAttemptId1,
            weeklyAttemptId,
          ],
        );

        final monthly = items.first;
        expect(monthly.sourceKind, WrongNoteSourceKind.mock);
        expect(monthly.mockSessionId, monthlySessionId);
        expect(monthly.mockType, MockExamType.monthly);
        expect(monthly.periodKey, '202602');
        expect(monthly.completedAt?.toUtc(), DateTime.utc(2026, 2, 24, 10, 0));

        final daily = items[1];
        expect(daily.sourceKind, WrongNoteSourceKind.daily);
        expect(daily.mockSessionId, isNull);
        expect(daily.mockType, isNull);
        expect(daily.periodKey, isNull);
        expect(daily.completedAt, isNull);
        expect(daily.dayKey, '2026-02-23');
      },
    );
  });
}
