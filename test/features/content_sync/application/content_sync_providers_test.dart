import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/content_sync/application/content_sync_providers.dart';
import 'package:resol_routine/features/settings/application/user_settings_providers.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

import '../../../test_helpers/fake_auth_session.dart';

void main() {
  group('PublishedContentSyncController', () {
    test('does not flush content sync while signed out', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      var requestCount = 0;

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          jsonApiClientProvider.overrideWithValue(
            JsonApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((http.Request request) async {
                requestCount += 1;
                return http.Response('{}', 200);
              }),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(publishedContentSyncControllerProvider.notifier)
          .syncCurrentTrack();
      expect(result, isNull);
      expect(requestCount, 0);
      expect(
        container.read(publishedContentSyncControllerProvider).status,
        PublishedContentSyncStatus.idle,
      );
    });

    test('syncCurrentTrack loads active content for signed-in student', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final settingsRepository = UserSettingsRepository(database: database);
      await settingsRepository.updateTrack('H1');

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(userId: 'student-1'),
          jsonApiClientProvider.overrideWithValue(
            JsonApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((http.Request request) async {
                if (request.url.path == '/public/content/sync') {
                  expect(request.url.queryParameters['track'], 'H1');
                  return http.Response(
                    jsonEncode(<String, Object?>{
                      'upserts': <Object?>[
                        <String, Object?>{
                          'unitId': 'unit-1',
                          'revisionId': 'revision-1',
                          'track': 'H1',
                          'skill': 'READING',
                          'typeTag': 'R_SUMMARY',
                          'difficulty': 3,
                          'publishedAt': '2026-03-15T00:00:00Z',
                          'hasAudio': false,
                        },
                      ],
                      'deletes': <Object?>[],
                      'nextCursor': 'cursor-1',
                      'hasMore': false,
                    }),
                    200,
                    headers: <String, String>{'content-type': 'application/json'},
                  );
                }
                if (request.url.path == '/public/content/units/revision-1') {
                  return http.Response(
                    jsonEncode(<String, Object?>{
                      'unitId': 'unit-1',
                      'revisionId': 'revision-1',
                      'track': 'H1',
                      'skill': 'READING',
                      'typeTag': 'R_SUMMARY',
                      'difficulty': 3,
                      'publishedAt': '2026-03-15T00:00:00Z',
                      'contentSourcePolicy': 'AI_ORIGINAL',
                      'bodyText': 'Some students assume that more time always leads to better decisions. However, the strongest teams often spend their time clarifying priorities before they act. As a result, efficient planning matters more than endless discussion.',
                      'question': <String, Object?>{
                        'stem': 'What is the main idea of the passage?',
                        'options': <String, Object?>{
                          'A': 'Efficient planning can matter more than taking more time.',
                          'B': 'Every long discussion leads to a better choice.',
                          'C': 'Students should avoid teamwork whenever possible.',
                          'D': 'Strong teams always finish their tasks slowly.',
                          'E': 'Clarifying priorities wastes time in group work.',
                        },
                        'answerKey': 'A',
                        'explanation': 'The passage contrasts long discussion with efficient planning.',
                        'evidenceSentenceIds': <Object?>['s2', 's3'],
                        'whyCorrectKo': '핵심 대비 문장을 종합하면 계획의 효율성이 핵심이다.',
                        'whyWrongKoByOption': <String, Object?>{
                          'A': '정답이다.',
                          'B': '지문과 반대다.',
                          'C': '팀워크 자체를 부정하지 않는다.',
                          'D': '속도와 직접 연결하지 않는다.',
                          'E': '우선순위 정리가 낭비라고 하지 않는다.',
                        },
                      },
                    }),
                    200,
                    headers: <String, String>{'content-type': 'application/json'},
                  );
                }
                fail('Unexpected path: ${request.url}');
              }),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userSettingsProvider.future);
      container.invalidate(selectedTrackProvider);
      expect(container.read(selectedTrackProvider), 'H1');

      final result = await container
          .read(publishedContentSyncControllerProvider.notifier)
          .syncCurrentTrack();

      expect(result, isNotNull);
      expect(result!.track, 'H1');
      expect(result.activeItemCount, 1);
      expect(
        container.read(publishedContentSyncControllerProvider).status,
        PublishedContentSyncStatus.success,
      );

      final snapshot = await container.read(
        publishedContentSyncSnapshotProvider('H1').future,
      );
      expect(snapshot.activeItemCount, 1);
      expect(snapshot.lastSyncCursor, 'cursor-1');
    });
  });
}
