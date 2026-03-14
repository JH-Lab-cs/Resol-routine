import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_sync/data/content_sync_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_attempt_repository.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_period_key.dart';
import 'package:resol_routine/features/mock_exam/data/mock_exam_session_repository.dart';

void main() {
  group('MockExamSessionRepository', () {
    late AppDatabase database;
    late MockExamSessionRepository repository;
    late MockExamAttemptRepository attemptRepository;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = MockExamSessionRepository(database: database);
      attemptRepository = MockExamAttemptRepository(database: database);
      await _seedQuestionPool(
        database,
        track: 'M3',
        listeningCount: 12,
        readingCount: 12,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('returns same session id for same type-period-track', () async {
      final nowLocal = DateTime.utc(2026, 2, 20, 1, 30);
      final plan = MockExamSessionRepository.weeklyDefaultPlan;

      final first = await repository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: plan,
        nowLocal: nowLocal,
      );
      final second = await repository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: plan,
        nowLocal: nowLocal,
      );

      expect(first.sessionId, second.sessionId);
      expect(first.periodKey, second.periodKey);
      expect(
        first.items.map((item) => item.questionId).toList(),
        hasLength(20),
      );
      expect(first.items.map((item) => item.questionId).toSet(), hasLength(20));

      expect(
        first.items.take(10).every((item) => item.skill == Skill.listening),
        isTrue,
      );
      expect(
        first.items.skip(10).every((item) => item.skill == Skill.reading),
        isTrue,
      );

      expect(first.periodKey, startsWith('2026W'));
      validateMockExamPeriodKey(
        type: MockExamType.weekly,
        periodKey: first.periodKey,
      );
    });

    test(
      'deterministically selects same question set within same period',
      () async {
        final nowLocal = DateTime.utc(2026, 2, 20, 1, 30);
        final plan = MockExamSessionRepository.weeklyDefaultPlan;

        final first = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: plan,
          nowLocal: nowLocal,
        );
        final firstQuestionIds = first.items
            .map((item) => item.questionId)
            .toList(growable: false);

        await (database.delete(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(first.sessionId))).go();

        final second = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: plan,
          nowLocal: nowLocal,
        );
        final secondQuestionIds = second.items
            .map((item) => item.questionId)
            .toList(growable: false);

        expect(firstQuestionIds, orderedEquals(secondQuestionIds));
      },
    );

    test(
      'throws INSUFFICIENT_QUESTIONS when question pool is too small',
      () async {
        expect(
          () => repository.getOrCreateSession(
            type: MockExamType.weekly,
            track: 'M3',
            plan: const MockExamQuestionPlan(
              listeningCount: 13,
              readingCount: 10,
            ),
            nowLocal: DateTime.utc(2026, 2, 20, 1, 30),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('INSUFFICIENT_QUESTIONS'),
            ),
          ),
        );
      },
    );

    test('prefers active synced content and excludes inactive remote questions', () async {
      for (var index = 0; index < 10; index++) {
        await _seedSyncedMockQuestion(
          database,
          revisionId: 'revision-listening-$index',
          unitId: 'unit-listening-$index',
          track: 'M3',
          skill: Skill.listening,
          active: true,
        );
        await _seedSyncedMockQuestion(
          database,
          revisionId: 'revision-reading-$index',
          unitId: 'unit-reading-$index',
          track: 'M3',
          skill: Skill.reading,
          active: true,
        );
      }
      await _seedSyncedMockQuestion(
        database,
        revisionId: 'revision-listening-inactive',
        unitId: 'unit-listening-inactive',
        track: 'M3',
        skill: Skill.listening,
        active: false,
      );

      final session = await repository.getOrCreateSession(
        type: MockExamType.weekly,
        track: 'M3',
        plan: MockExamSessionRepository.weeklyDefaultPlan,
        nowLocal: DateTime.utc(2026, 2, 21, 9),
      );

      expect(
        session.items.take(10).map((item) => item.questionId),
        everyElement(startsWith('remote:question:revision-listening-')),
      );
      expect(
        session.items.skip(10).map((item) => item.questionId),
        everyElement(startsWith('remote:question:revision-reading-')),
      );
      expect(
        session.items.map((item) => item.questionId),
        isNot(contains('remote:question:revision-listening-inactive')),
      );
    });

    test(
      'listRecent returns summaries sorted by period with score counts',
      () async {
        final olderSession = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 20, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: olderSession.sessionId,
          questionId: olderSession.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: olderSession.sessionId,
          questionId: olderSession.items[1].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );

        final newerSession = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 2, 27, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: newerSession.sessionId,
          questionId: newerSession.items[0].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: newerSession.sessionId,
          questionId: newerSession.items[1].questionId,
          selectedAnswer: 'A',
          isCorrect: true,
        );

        final summaries = await repository.listRecent(
          type: MockExamType.weekly,
          track: 'M3',
          limit: 10,
        );

        expect(summaries, hasLength(2));
        expect(summaries.first.sessionId, newerSession.sessionId);
        expect(summaries.first.correctCount, 2);
        expect(summaries.first.wrongCount, 0);

        expect(summaries.last.sessionId, olderSession.sessionId);
        expect(summaries.last.correctCount, 1);
        expect(summaries.last.wrongCount, 1);
      },
    );

    test(
      'deleteSessionById removes session items and attempts together',
      () async {
        final session = await repository.getOrCreateSession(
          type: MockExamType.weekly,
          track: 'M3',
          plan: const MockExamQuestionPlan(listeningCount: 2, readingCount: 2),
          nowLocal: DateTime.utc(2026, 3, 2, 9, 0),
        );
        await attemptRepository.saveAttemptIdempotent(
          mockSessionId: session.sessionId,
          questionId: session.items[0].questionId,
          selectedAnswer: 'B',
          isCorrect: false,
          wrongReasonTag: WrongReasonTag.vocab,
        );

        await repository.deleteSessionById(session.sessionId);

        final deletedSession = await (database.select(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(session.sessionId))).getSingleOrNull();
        final remainingItems = await (database.select(
          database.mockExamSessionItems,
        )..where((tbl) => tbl.sessionId.equals(session.sessionId))).get();
        final remainingAttempts = await (database.select(
          database.attempts,
        )..where((tbl) => tbl.mockSessionId.equals(session.sessionId))).get();

        expect(deletedSession, isNull);
        expect(remainingItems, isEmpty);
        expect(remainingAttempts, isEmpty);
      },
    );

    test(
      'pruneOldSessions keeps recent completed sessions and preserves in-progress sessions',
      () async {
        final weeklyIds = <int>[];
        final monthlyIds = <int>[];
        for (var i = 0; i < 60; i++) {
          final completedAt = DateTime.utc(
            2026,
            12,
            31,
          ).subtract(Duration(days: i * 7));
          final weekValue = (i % 52) + 1;
          final year = 2026 - (i ~/ 52);
          final periodKey = '${year}W${weekValue.toString().padLeft(2, '0')}';
          final id = await database
              .into(database.mockExamSessions)
              .insert(
                MockExamSessionsCompanion.insert(
                  examType: MockExamType.weekly.dbValue,
                  periodKey: periodKey,
                  track: 'M3',
                  plannedItems: 20,
                  completedItems: const Value(20),
                  completedAt: Value(completedAt),
                ),
              );
          weeklyIds.add(id);
        }
        for (var i = 0; i < 20; i++) {
          final completedAt = DateTime.utc(
            2026,
            12,
            31,
          ).subtract(Duration(days: i * 30));
          final monthDate = DateTime.utc(2026, 12 - i, 1);
          final periodKey =
              '${monthDate.year.toString().padLeft(4, '0')}${monthDate.month.toString().padLeft(2, '0')}';
          final id = await database
              .into(database.mockExamSessions)
              .insert(
                MockExamSessionsCompanion.insert(
                  examType: MockExamType.monthly.dbValue,
                  periodKey: periodKey,
                  track: 'M3',
                  plannedItems: 45,
                  completedItems: const Value(45),
                  completedAt: Value(completedAt),
                ),
              );
          monthlyIds.add(id);
        }

        final inProgressWeeklyId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.weekly.dbValue,
                periodKey: '2026W53',
                track: 'M3',
                plannedItems: 20,
                completedItems: const Value(3),
                completedAt: const Value(null),
              ),
            );
        final inProgressMonthlyId = await database
            .into(database.mockExamSessions)
            .insert(
              MockExamSessionsCompanion.insert(
                examType: MockExamType.monthly.dbValue,
                periodKey: '202701',
                track: 'M3',
                plannedItems: 45,
                completedItems: const Value(4),
                completedAt: const Value(null),
              ),
            );

        await repository.pruneOldSessions(weeklyKeep: 52, monthlyKeep: 12);

        final remainingWeeklyCompleted = await database
            .customSelect(
              'SELECT id FROM mock_exam_sessions '
              'WHERE exam_type = ? AND completed_at IS NOT NULL '
              'ORDER BY completed_at DESC, id DESC',
              variables: [Variable<String>(MockExamType.weekly.dbValue)],
              readsFrom: {database.mockExamSessions},
            )
            .get();
        final remainingMonthlyCompleted = await database
            .customSelect(
              'SELECT id FROM mock_exam_sessions '
              'WHERE exam_type = ? AND completed_at IS NOT NULL '
              'ORDER BY completed_at DESC, id DESC',
              variables: [Variable<String>(MockExamType.monthly.dbValue)],
              readsFrom: {database.mockExamSessions},
            )
            .get();

        expect(remainingWeeklyCompleted, hasLength(52));
        expect(remainingMonthlyCompleted, hasLength(12));
        expect(
          remainingWeeklyCompleted.map((row) => row.read<int>('id')).toSet(),
          equals(weeklyIds.take(52).toSet()),
        );
        expect(
          remainingMonthlyCompleted.map((row) => row.read<int>('id')).toSet(),
          equals(monthlyIds.take(12).toSet()),
        );

        final inProgressWeekly = await (database.select(
          database.mockExamSessions,
        )..where((tbl) => tbl.id.equals(inProgressWeeklyId))).getSingleOrNull();
        final inProgressMonthly =
            await (database.select(database.mockExamSessions)
                  ..where((tbl) => tbl.id.equals(inProgressMonthlyId)))
                .getSingleOrNull();
        expect(inProgressWeekly, isNotNull);
        expect(inProgressMonthly, isNotNull);
      },
    );
  });
}

Future<void> _ensurePublishedSyncPack(AppDatabase database) async {
  await database.into(database.contentPacks).insertOnConflictUpdate(
    ContentPacksCompanion(
      id: const Value(publishedContentPackId),
      version: const Value(1),
      locale: const Value('en-US'),
      title: const Value(publishedContentPackTitle),
      description: const Value('Synced published content'),
      checksum: const Value('published-content-sync-v1'),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );
}

Future<void> _seedSyncedMockQuestion(
  AppDatabase database, {
  required String revisionId,
  required String unitId,
  required String track,
  required Skill skill,
  required bool active,
}) async {
  await _ensurePublishedSyncPack(database);
  final sourceId = skill == Skill.reading
      ? 'remote:passage:$revisionId'
      : 'remote:script:$revisionId';
  final questionId = 'remote:question:$revisionId';
  final explanationId = 'remote:explanation:$revisionId';
  final now = DateTime.now().toUtc();

  if (skill == Skill.reading) {
    await database.into(database.passages).insertOnConflictUpdate(
      PassagesCompanion(
        id: Value(sourceId),
        packId: const Value(publishedContentPackId),
        title: Value('$track passage $revisionId'),
        sentencesJson: Value(const <Sentence>[
          Sentence(id: 's1', text: 'Planning reduces confusion in long projects.'),
          Sentence(id: 's2', text: 'Teams benefit when they clarify roles early.'),
        ]),
        orderIndex: const Value(0),
      ),
    );
  } else {
    await database.into(database.scripts).insertOnConflictUpdate(
      ScriptsCompanion(
        id: Value(sourceId),
        packId: const Value(publishedContentPackId),
        sentencesJson: const Value(<Sentence>[
          Sentence(id: 's1', text: 'Please review the schedule before the meeting.'),
          Sentence(id: 's2', text: 'I will update the board this afternoon.'),
        ]),
        turnsJson: const Value(<Turn>[
          Turn(speaker: 'S1', sentenceIds: <String>['s1']),
          Turn(speaker: 'S2', sentenceIds: <String>['s2']),
        ]),
        ttsPlanJson: const Value(
          TtsPlan(
            repeatPolicy: <String, Object?>{'type': 'single'},
            pauseRangeMs: NumericRange(min: 150, max: 300),
            rateRange: NumericRange(min: 0.95, max: 1.0),
            pitchRange: NumericRange(min: -1.0, max: 1.0),
            voiceRoles: <String, String>{
              'S1': 'alloy',
              'S2': 'nova',
              'N': 'alloy',
            },
          ),
        ),
        orderIndex: const Value(0),
      ),
    );
  }

  await database.into(database.questions).insertOnConflictUpdate(
    QuestionsCompanion(
      id: Value(questionId),
      skill: Value(skill.dbValue),
      typeTag: Value(skill == Skill.reading ? 'R_ORDER' : 'L_DETAIL'),
      track: Value(track),
      difficulty: const Value(3),
      passageId: Value(skill == Skill.reading ? sourceId : null),
      scriptId: Value(skill == Skill.listening ? sourceId : null),
      prompt: Value(
        skill == Skill.reading
            ? 'What is the best order of the sentences?'
            : 'What will the student most likely do next?',
      ),
      optionsJson: const Value(
        OptionMap(
          a: 'A',
          b: 'B',
          c: 'C',
          d: 'D',
          e: 'E',
        ),
      ),
      answerKey: const Value('A'),
      orderIndex: const Value(0),
    ),
  );
  await database.into(database.explanations).insertOnConflictUpdate(
    ExplanationsCompanion(
      id: Value(explanationId),
      questionId: Value(questionId),
      evidenceSentenceIdsJson: const Value(<String>['s1', 's2']),
      whyCorrectKo: const Value('핵심 정보가 앞뒤로 자연스럽게 연결된다.'),
      whyWrongKoJson: const Value(
        OptionMap(
          a: '정답이다.',
          b: '문맥과 어긋난다.',
          c: '문맥과 어긋난다.',
          d: '문맥과 어긋난다.',
          e: '문맥과 어긋난다.',
        ),
      ),
      structureNotesKo: const Value('연결 관계를 추적한다.'),
    ),
  );
  await database
      .into(database.publishedContentCacheEntries)
      .insertOnConflictUpdate(
        PublishedContentCacheEntriesCompanion(
          revisionId: Value(revisionId),
          unitId: Value(unitId),
          questionId: Value(questionId),
          explanationId: Value(explanationId),
          passageId: Value(skill == Skill.reading ? sourceId : null),
          scriptId: Value(skill == Skill.listening ? sourceId : null),
          track: Value(track),
          skill: Value(skill.dbValue),
          typeTag: Value(skill == Skill.reading ? 'R_ORDER' : 'L_DETAIL'),
          difficulty: const Value(3),
          contentSourcePolicy: const Value('AI_ORIGINAL'),
          hasAudio: Value(skill == Skill.listening),
          assetId: Value(skill == Skill.listening ? 'asset-$revisionId' : null),
          assetMimeType: Value(skill == Skill.listening ? 'audio/mpeg' : null),
          isActive: Value(active),
          publishedAt: Value(now),
          syncedAt: Value(now),
        ),
      );
}

Future<void> _seedQuestionPool(
  AppDatabase database, {
  required String track,
  required int listeningCount,
  required int readingCount,
}) async {
  final packId = 'pack_$track';
  final scriptId = 'script_$track';
  final passageId = 'passage_$track';

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
          sentencesJson: const <Sentence>[Sentence(id: 's1', text: 'line')],
          turnsJson: const <Turn>[
            Turn(speaker: 'S1', sentenceIds: <String>['s1']),
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
          sentencesJson: const <Sentence>[Sentence(id: 'p1', text: 'line')],
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

  for (var i = 0; i < listeningCount; i++) {
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: 'Q_${track}_L_${i + 1}',
            skill: Skill.listening.dbValue,
            typeTag: 'L${i + 1}',
            track: track,
            difficulty: 2,
            passageId: const Value(null),
            scriptId: Value(scriptId),
            prompt: 'Listening question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: i,
          ),
        );
  }

  for (var i = 0; i < readingCount; i++) {
    await database
        .into(database.questions)
        .insert(
          QuestionsCompanion.insert(
            id: 'Q_${track}_R_${i + 1}',
            skill: Skill.reading.dbValue,
            typeTag: 'R${i + 1}',
            track: track,
            difficulty: 2,
            passageId: Value(passageId),
            scriptId: const Value(null),
            prompt: 'Reading question ${i + 1}',
            optionsJson: options,
            answerKey: 'A',
            orderIndex: i + listeningCount,
          ),
        );
  }
}
