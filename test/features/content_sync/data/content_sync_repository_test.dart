import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/content_sync/data/content_sync_repository.dart';

void main() {
  group('PublishedContentSyncRepository', () {
    test('first sync stores published revision locally and updates cursor', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final repository = PublishedContentSyncRepository(
        database: database,
        apiClient: JsonApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((http.Request request) async {
            if (request.url.path == '/public/content/sync') {
              expect(request.url.queryParameters['track'], 'M3');
              return _jsonResponse(<String, Object?>{
                'upserts': <Object?>[
                  <String, Object?>{
                    'unitId': 'unit-1',
                    'revisionId': 'revision-1',
                    'track': 'M3',
                    'skill': 'READING',
                    'typeTag': 'R_VOCAB',
                    'difficulty': 2,
                    'publishedAt': '2026-03-15T00:00:00Z',
                    'hasAudio': false,
                  },
                ],
                'deletes': <Object?>[],
                'nextCursor': 'cursor-1',
                'hasMore': false,
              });
            }
            if (request.url.path == '/public/content/units/revision-1') {
              return _jsonResponse(_readingDetailPayload(
                unitId: 'unit-1',
                revisionId: 'revision-1',
                track: 'M3',
                typeTag: 'R_VOCAB',
                difficulty: 2,
              ));
            }
            fail('Unexpected path: ${request.url}');
          }),
        ),
      );

      final result = await repository.syncTrack(track: 'M3');
      expect(result.upserted, 1);
      expect(result.deleted, 0);
      expect(result.lastCursor, 'cursor-1');
      expect(await database.countPublishedContentCacheEntries(), 1);

      final snapshot = await repository.getSnapshot(track: 'M3');
      expect(snapshot.activeItemCount, 1);
      expect(snapshot.lastSyncCursor, 'cursor-1');
      expect(snapshot.lastSyncErrorCode, isNull);

      final question = await (database.select(
        database.questions,
      )..where((tbl) => tbl.id.equals('remote:question:revision-1'))).getSingle();
      expect(question.prompt, contains('methodical'));

      final cacheEntry = await (database.select(
        database.publishedContentCacheEntries,
      )..where((tbl) => tbl.revisionId.equals('revision-1'))).getSingle();
      expect(cacheEntry.isActive, isTrue);
      expect(cacheEntry.hasAudio, isFalse);
      expect(cacheEntry.assetId, isNull);
    });

    test('subsequent sync uses cursor, applies tombstone, and keeps signed URL out of local content rows', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      var syncCallCount = 0;

      final repository = PublishedContentSyncRepository(
        database: database,
        apiClient: JsonApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((http.Request request) async {
            if (request.url.path == '/public/content/sync') {
              syncCallCount += 1;
              if (syncCallCount == 1) {
                expect(request.url.queryParameters['cursor'], isNull);
                return _jsonResponse(<String, Object?>{
                  'upserts': <Object?>[
                    <String, Object?>{
                      'unitId': 'unit-listening',
                      'revisionId': 'revision-a',
                      'track': 'H1',
                      'skill': 'LISTENING',
                      'typeTag': 'L_DETAIL',
                      'difficulty': 2,
                      'publishedAt': '2026-03-15T00:00:00Z',
                      'hasAudio': true,
                    },
                  ],
                  'deletes': <Object?>[],
                  'nextCursor': 'cursor-a',
                  'hasMore': true,
                });
              }
              expect(request.url.queryParameters['cursor'], 'cursor-a');
              return _jsonResponse(<String, Object?>{
                'upserts': <Object?>[
                  <String, Object?>{
                    'unitId': 'unit-listening',
                    'revisionId': 'revision-b',
                    'track': 'H1',
                    'skill': 'LISTENING',
                    'typeTag': 'L_DETAIL',
                    'difficulty': 2,
                    'publishedAt': '2026-03-16T00:00:00Z',
                    'hasAudio': true,
                  },
                ],
                'deletes': <Object?>[
                  <String, Object?>{
                    'unitId': 'unit-listening',
                    'revisionId': 'revision-a',
                    'reason': 'UNPUBLISHED',
                    'changedAt': '2026-03-16T00:00:00Z',
                  },
                ],
                'nextCursor': 'cursor-b',
                'hasMore': false,
              });
            }
            if (request.url.path == '/public/content/units/revision-a') {
              return _jsonResponse(_listeningDetailPayload(
                unitId: 'unit-listening',
                revisionId: 'revision-a',
                publishedAt: '2026-03-15T00:00:00Z',
              ));
            }
            if (request.url.path == '/public/content/units/revision-b') {
              return _jsonResponse(_listeningDetailPayload(
                unitId: 'unit-listening',
                revisionId: 'revision-b',
                publishedAt: '2026-03-16T00:00:00Z',
              ));
            }
            fail('Unexpected path: ${request.url}');
          }),
        ),
      );

      final result = await repository.syncTrack(track: 'H1');
      expect(result.pagesFetched, 2);
      expect(result.upserted, 2);
      expect(result.deleted, 1);
      expect(result.lastCursor, 'cursor-b');
      expect(result.activeItemCount, 1);

      final allEntries = await (database.select(database.publishedContentCacheEntries)
            ..where((tbl) => tbl.unitId.equals('unit-listening')))
          .get();
      expect(allEntries, hasLength(2));
      final inactiveEntry = allEntries.singleWhere((row) => row.revisionId == 'revision-a');
      final activeEntry = allEntries.singleWhere((row) => row.revisionId == 'revision-b');
      expect(inactiveEntry.isActive, isFalse);
      expect(activeEntry.isActive, isTrue);
      expect(activeEntry.assetId, 'asset-revision-b');
      expect(activeEntry.assetMimeType, 'audio/mpeg');

      final script = await (database.select(
        database.scripts,
      )..where((tbl) => tbl.id.equals('remote:script:revision-b'))).getSingle();
      expect(script.sentencesJson, hasLength(greaterThanOrEqualTo(2)));
      expect(script.turnsJson, isNotEmpty);

      final questionRows = await database.select(database.questions).get();
      expect(questionRows, hasLength(2));
      expect(
        questionRows.map((row) => row.id),
        containsAll(<String>['remote:question:revision-a', 'remote:question:revision-b']),
      );

      final snapshot = await repository.getSnapshot(track: 'H1');
      expect(snapshot.lastSyncCursor, 'cursor-b');
      expect(snapshot.activeItemCount, 1);
    });
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

Map<String, Object?> _readingDetailPayload({
  required String unitId,
  required String revisionId,
  required String track,
  required String typeTag,
  required int difficulty,
}) {
  return <String, Object?>{
    'unitId': unitId,
    'revisionId': revisionId,
    'track': track,
    'skill': 'READING',
    'typeTag': typeTag,
    'difficulty': difficulty,
    'publishedAt': '2026-03-15T00:00:00Z',
    'contentSourcePolicy': 'AI_ORIGINAL',
    'bodyText': 'Although the workshop looked chaotic at first, the director followed a methodical plan. She assigned each volunteer a narrow task so that the team would not duplicate work. By the afternoon, the room felt orderly because everyone understood their role.',
    'question': <String, Object?>{
      'stem': 'Which meaning best fits the word "methodical" in the passage?',
      'options': <String, Object?>{
        'A': 'carefully organized',
        'B': 'easily forgotten',
        'C': 'strangely decorated',
        'D': 'publicly ignored',
        'E': 'lightly painted',
      },
      'answerKey': 'A',
      'explanation': 'The surrounding context describes a careful step-by-step plan.',
      'evidenceSentenceIds': <Object?>['s1', 's2'],
      'whyCorrectKo': '문맥상 체계적으로 역할을 나눴다는 의미다.',
      'whyWrongKoByOption': <String, Object?>{
        'A': '정답이다.',
        'B': '문맥과 맞지 않는다.',
        'C': '장식에 대한 설명이 아니다.',
        'D': '무시당했다는 의미가 아니다.',
        'E': '색칠과 관련이 없다.',
      },
      'vocabNotesKo': 'methodical = 체계적인',
      'structureNotesKo': '앞뒤 문맥에서 계획성과 질서를 확인한다.',
    },
  };
}

Map<String, Object?> _listeningDetailPayload({
  required String unitId,
  required String revisionId,
  required String publishedAt,
}) {
  return <String, Object?>{
    'unitId': unitId,
    'revisionId': revisionId,
    'track': 'H1',
    'skill': 'LISTENING',
    'typeTag': 'L_DETAIL',
    'difficulty': 2,
    'publishedAt': publishedAt,
    'contentSourcePolicy': 'AI_ORIGINAL',
    'transcriptText': 'Guide: Please check the entrance sign before the visitors arrive.\nVolunteer: I will replace the loose sign and bring another lamp.',
    'ttsPlan': <String, Object?>{
      'repeatPolicy': <String, Object?>{'type': 'single'},
      'pauseRangeMs': <String, Object?>{'min': 150, 'max': 300},
      'rateRange': <String, Object?>{'min': 0.95, 'max': 1.0},
      'pitchRange': <String, Object?>{'min': -1.0, 'max': 1.0},
      'voiceRoles': <String, Object?>{
        'S1': 'alloy',
        'S2': 'nova',
        'N': 'alloy',
      },
    },
    'asset': <String, Object?>{
      'assetId': 'asset-$revisionId',
      'mimeType': 'audio/mpeg',
      'signedUrl': 'https://signed.example.test/$revisionId',
      'expiresInSeconds': 600,
    },
    'question': <String, Object?>{
      'stem': 'What is the volunteer most likely to do next?',
      'options': <String, Object?>{
        'A': 'Replace the sign and bring a lamp.',
        'B': 'Cancel the event immediately.',
        'C': 'Move the visitors outside.',
        'D': 'Ask the guide to leave early.',
        'E': 'Borrow a book from the library.',
      },
      'answerKey': 'A',
      'explanation': 'The volunteer states both actions directly.',
      'evidenceSentenceIds': <Object?>['s1', 's2'],
      'whyCorrectKo': '마지막 발화에 다음 행동이 직접 나온다.',
      'whyWrongKoByOption': <String, Object?>{
        'A': '정답이다.',
        'B': '행사 취소 이야기는 없다.',
        'C': '방문객을 밖으로 옮긴다는 말은 없다.',
        'D': '가이드의 조기 퇴장과 무관하다.',
        'E': '도서관 언급이 없다.',
      },
      'structureNotesKo': '두 발화의 정보 결합으로 정답을 고른다.',
    },
  };
}
