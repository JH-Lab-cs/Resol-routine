import 'dart:io';

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
  });
}
