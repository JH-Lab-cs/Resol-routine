import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/converters/json_models.dart';
import 'package:resol_routine/core/domain/domain_enums.dart';
import 'package:resol_routine/features/content_pack/data/content_pack_seeder.dart';
import 'package:resol_routine/features/content_sync/data/content_sync_repository.dart';
import 'package:resol_routine/features/today/data/today_session_repository.dart';

void main() {
  group('TodaySessionRepository', () {
    late AppDatabase database;
    late String starterPackJson;
    late TodaySessionRepository repository;

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

      repository = TodaySessionRepository(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'same dayKey and track returns identical items with six unique entries',
      () async {
        final nowLocal = DateTime(2026, 2, 19, 9, 30);

        final first = await repository.getOrCreateSession(
          track: 'M3',
          nowLocal: nowLocal,
        );
        final second = await repository.getOrCreateSession(
          track: 'M3',
          nowLocal: nowLocal,
        );

        final firstSignature = first.items
            .map((item) => '${item.orderIndex}:${item.questionId}')
            .toList(growable: false);
        final secondSignature = second.items
            .map((item) => '${item.orderIndex}:${item.questionId}')
            .toList(growable: false);

        expect(firstSignature, orderedEquals(secondSignature));
        expect(first.items, hasLength(6));
        expect(
          first.items.map((item) => item.questionId).toSet(),
          hasLength(6),
        );

        final row = await database
            .customSelect(
              'SELECT COUNT(*) AS item_count '
              'FROM daily_session_items WHERE session_id = ?',
              variables: [Variable<int>(first.sessionId)],
              readsFrom: {database.dailySessionItems},
            )
            .getSingle();
        expect(row.read<int>('item_count'), 6);
      },
    );

    test('order_index and skill order match [L, L, L, R, R, R]', () async {
      final bundle = await repository.getOrCreateSession(
        track: 'H1',
        nowLocal: DateTime(2026, 2, 19, 10, 0),
      );

      expect(
        bundle.items.map((item) => item.orderIndex).toList(growable: false),
        orderedEquals(<int>[0, 1, 2, 3, 4, 5]),
      );
      expect(
        bundle.items.map((item) => item.skill).toList(growable: false),
        orderedEquals(<String>[
          'LISTENING',
          'LISTENING',
          'LISTENING',
          'READING',
          'READING',
          'READING',
        ]),
      );
    });

    test(
      'scheduler remains deterministic across repeated runs in process',
      () async {
        final nowLocal = DateTime(2026, 2, 19, 12, 0);

        final first = await repository.getOrCreateSession(
          track: 'H2',
          nowLocal: nowLocal,
        );
        final firstQuestionIds = first.items
            .map((item) => item.questionId)
            .toList(growable: false);

        await (database.delete(
          database.dailySessions,
        )..where((tbl) => tbl.id.equals(first.sessionId))).go();

        final second = await repository.getOrCreateSession(
          track: 'H2',
          nowLocal: nowLocal,
        );
        final secondQuestionIds = second.items
            .map((item) => item.questionId)
            .toList(growable: false);

        expect(firstQuestionIds, orderedEquals(secondQuestionIds));
      },
    );

    test('saveSectionOrder persists metadata and reorders items', () async {
      final bundle = await repository.getOrCreateSession(
        track: 'H2',
        nowLocal: DateTime(2026, 2, 19, 13, 0),
      );

      final updated = await repository.saveSectionOrder(
        sessionId: bundle.sessionId,
        sectionOrder: DailySectionOrder.readingFirst,
      );

      expect(updated.sectionOrder, DailySectionOrder.readingFirst);
      expect(
        updated.items.map((item) => item.skill).toList(growable: false),
        orderedEquals(<String>[
          'READING',
          'READING',
          'READING',
          'LISTENING',
          'LISTENING',
          'LISTENING',
        ]),
      );
    });

    test('prefers active synced content and excludes inactive remote items', () async {
      await _seedSyncedListeningQuestion(
        database,
        revisionId: 'revision-l-1',
        unitId: 'unit-l-1',
        track: 'H1',
        active: true,
      );
      await _seedSyncedListeningQuestion(
        database,
        revisionId: 'revision-l-2',
        unitId: 'unit-l-2',
        track: 'H1',
        active: true,
      );
      await _seedSyncedListeningQuestion(
        database,
        revisionId: 'revision-l-3',
        unitId: 'unit-l-3',
        track: 'H1',
        active: true,
      );
      await _seedSyncedListeningQuestion(
        database,
        revisionId: 'revision-l-inactive',
        unitId: 'unit-l-inactive',
        track: 'H1',
        active: false,
      );
      await _seedSyncedReadingQuestion(
        database,
        revisionId: 'revision-r-1',
        unitId: 'unit-r-1',
        track: 'H1',
        active: true,
      );
      await _seedSyncedReadingQuestion(
        database,
        revisionId: 'revision-r-2',
        unitId: 'unit-r-2',
        track: 'H1',
        active: true,
      );
      await _seedSyncedReadingQuestion(
        database,
        revisionId: 'revision-r-3',
        unitId: 'unit-r-3',
        track: 'H1',
        active: true,
      );

      final bundle = await repository.getOrCreateSession(
        track: 'H1',
        nowLocal: DateTime(2026, 2, 20, 8, 0),
      );

      final selectedIds = bundle.items
          .map((item) => item.questionId)
          .toList(growable: false);
      expect(
        selectedIds.take(3),
        everyElement(startsWith('remote:question:revision-l-')),
      );
      expect(
        selectedIds.skip(3),
        everyElement(startsWith('remote:question:revision-r-')),
      );
      expect(selectedIds, isNot(contains('remote:question:revision-l-inactive')));
    });
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

Future<void> _seedSyncedReadingQuestion(
  AppDatabase database, {
  required String revisionId,
  required String unitId,
  required String track,
  required bool active,
}) async {
  await _ensurePublishedSyncPack(database);
  final passageId = 'remote:passage:$revisionId';
  final questionId = 'remote:question:$revisionId';
  final explanationId = 'remote:explanation:$revisionId';
  final now = DateTime.now().toUtc();

  await database.into(database.passages).insertOnConflictUpdate(
    PassagesCompanion(
      id: Value(passageId),
      packId: const Value(publishedContentPackId),
      title: Value('$track passage $revisionId'),
      sentencesJson: Value(const <Sentence>[
        Sentence(id: 's1', text: 'Students can improve by reviewing carefully.'),
        Sentence(id: 's2', text: 'Planning helps them avoid repeated mistakes.'),
      ]),
      orderIndex: const Value(0),
    ),
  );
  await database.into(database.questions).insertOnConflictUpdate(
    QuestionsCompanion(
      id: Value(questionId),
      skill: const Value('READING'),
      typeTag: const Value('R_SUMMARY'),
      track: Value(track),
      difficulty: const Value(3),
      passageId: Value(passageId),
      prompt: const Value('What is the main idea of the passage?'),
      optionsJson: const Value(
        OptionMap(
          a: 'Review and planning improve performance.',
          b: 'Mistakes should never be discussed again.',
          c: 'Students learn best without planning.',
          d: 'Repeated mistakes are unavoidable.',
          e: 'Practice matters only in summer.',
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
      whyCorrectKo: const Value('지문 전체의 요지를 묶으면 정답이 된다.'),
      whyWrongKoJson: const Value(
        OptionMap(
          a: '정답이다.',
          b: '극단적이다.',
          c: '지문과 반대다.',
          d: '과장된 진술이다.',
          e: '근거가 없다.',
        ),
      ),
      structureNotesKo: const Value('원인과 결과를 함께 읽는다.'),
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
          passageId: Value(passageId),
          track: Value(track),
          skill: const Value('READING'),
          typeTag: const Value('R_SUMMARY'),
          difficulty: const Value(3),
          contentSourcePolicy: const Value('AI_ORIGINAL'),
          hasAudio: const Value(false),
          isActive: Value(active),
          publishedAt: Value(now),
          syncedAt: Value(now),
        ),
      );
}

Future<void> _seedSyncedListeningQuestion(
  AppDatabase database, {
  required String revisionId,
  required String unitId,
  required String track,
  required bool active,
}) async {
  await _ensurePublishedSyncPack(database);
  final scriptId = 'remote:script:$revisionId';
  final questionId = 'remote:question:$revisionId';
  final explanationId = 'remote:explanation:$revisionId';
  final now = DateTime.now().toUtc();

  await database.into(database.scripts).insertOnConflictUpdate(
    ScriptsCompanion(
      id: Value(scriptId),
      packId: const Value(publishedContentPackId),
      sentencesJson: const Value(<Sentence>[
        Sentence(id: 's1', text: 'Please check the entrance poster.'),
        Sentence(id: 's2', text: 'I will replace it after lunch.'),
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
  await database.into(database.questions).insertOnConflictUpdate(
    QuestionsCompanion(
      id: Value(questionId),
      skill: const Value('LISTENING'),
      typeTag: const Value('L_DETAIL'),
      track: Value(track),
      difficulty: const Value(2),
      scriptId: Value(scriptId),
      prompt: const Value('What will the student most likely do next?'),
      optionsJson: const Value(
        OptionMap(
          a: 'Replace the entrance poster after lunch.',
          b: 'Cancel the lunch meeting.',
          c: 'Visit the library now.',
          d: 'Buy a new notebook today.',
          e: 'Call the principal later.',
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
      whyCorrectKo: const Value('마지막 응답에 다음 행동이 직접 나온다.'),
      whyWrongKoJson: const Value(
        OptionMap(
          a: '정답이다.',
          b: '점심 약속 취소와 무관하다.',
          c: '도서관 방문 언급이 없다.',
          d: '공책 구매와 관련 없다.',
          e: '교장에게 전화한다는 말이 없다.',
        ),
      ),
      structureNotesKo: const Value('두 발화를 연결해 행동을 추론한다.'),
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
          scriptId: Value(scriptId),
          track: Value(track),
          skill: const Value('LISTENING'),
          typeTag: const Value('L_DETAIL'),
          difficulty: const Value(2),
          contentSourcePolicy: const Value('AI_ORIGINAL'),
          hasAudio: const Value(true),
          assetId: Value('asset-$revisionId'),
          assetMimeType: const Value('audio/mpeg'),
          isActive: Value(active),
          publishedAt: Value(now),
          syncedAt: Value(now),
        ),
      );
}
