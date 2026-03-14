import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/content_sync/application/content_sync_providers.dart';
import 'package:resol_routine/features/settings/data/user_settings_repository.dart';

import '../../../test_helpers/fake_auth_session.dart';

void main() {
  testWidgets('signed-in widget sync increases local content count', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    await UserSettingsRepository(database: database).updateTrack('M3');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(),
          jsonApiClientProvider.overrideWithValue(
            JsonApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((http.Request request) async {
                if (request.url.path == '/public/content/sync') {
                  return http.Response(
                    jsonEncode(<String, Object?>{
                      'upserts': <Object?>[
                        <String, Object?>{
                          'unitId': 'unit-widget-1',
                          'revisionId': 'revision-widget-1',
                          'track': 'M3',
                          'skill': 'READING',
                          'typeTag': 'R_SUMMARY',
                          'difficulty': 2,
                          'publishedAt': '2026-03-15T00:00:00Z',
                          'hasAudio': false,
                        },
                      ],
                      'deletes': <Object?>[],
                      'nextCursor': 'cursor-widget-1',
                      'hasMore': false,
                    }),
                    200,
                    headers: <String, String>{'content-type': 'application/json'},
                  );
                }
                if (request.url.path == '/public/content/units/revision-widget-1') {
                  return http.Response(
                    jsonEncode(<String, Object?>{
                      'unitId': 'unit-widget-1',
                      'revisionId': 'revision-widget-1',
                      'track': 'M3',
                      'skill': 'READING',
                      'typeTag': 'R_SUMMARY',
                      'difficulty': 2,
                      'publishedAt': '2026-03-15T00:00:00Z',
                      'contentSourcePolicy': 'AI_ORIGINAL',
                      'bodyText': 'Students improve faster when they review evidence and assign clear roles before discussion begins. That preparation helps teams avoid repeated confusion.',
                      'question': <String, Object?>{
                        'stem': 'What is the main idea of the passage?',
                        'options': <String, Object?>{
                          'A': 'Preparation and role clarity reduce confusion.',
                          'B': 'Students should avoid all team activities.',
                          'C': 'Confusion is necessary for better decisions.',
                          'D': 'Discussion should come before all preparation.',
                          'E': 'Evidence review always wastes time.',
                        },
                        'answerKey': 'A',
                        'explanation': 'The passage connects preparation to reduced confusion.',
                        'evidenceSentenceIds': <Object?>['s1', 's2'],
                        'whyCorrectKo': '준비와 역할 정리가 핵심이라는 점이 반복된다.',
                        'whyWrongKoByOption': <String, Object?>{
                          'A': '정답이다.',
                          'B': '지문과 반대다.',
                          'C': '혼란을 긍정하지 않는다.',
                          'D': '준비의 중요성을 약화한다.',
                          'E': '증거 검토를 부정하지 않는다.',
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
        child: const MaterialApp(home: _ContentSyncSmokeScreen(track: 'M3')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('status:success'), findsOneWidget);
    expect(find.text('count:1'), findsOneWidget);
    expect(await database.countPublishedContentCacheEntries(), 1);
  });

  testWidgets('sync failure renders error state', (WidgetTester tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(),
          jsonApiClientProvider.overrideWithValue(
            JsonApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((http.Request request) async {
                return http.Response(
                  jsonEncode(<String, Object?>{
                    'detail': 'server_error',
                    'errorCode': 'server_error',
                  }),
                  500,
                  headers: <String, String>{'content-type': 'application/json'},
                );
              }),
            ),
          ),
        ],
        child: const MaterialApp(home: _ContentSyncSmokeScreen(track: 'M3')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('status:error'), findsOneWidget);
  });
}

class _ContentSyncSmokeScreen extends ConsumerStatefulWidget {
  const _ContentSyncSmokeScreen({required this.track});

  final String track;

  @override
  ConsumerState<_ContentSyncSmokeScreen> createState() =>
      _ContentSyncSmokeScreenState();
}

class _ContentSyncSmokeScreenState extends ConsumerState<_ContentSyncSmokeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(publishedContentSyncControllerProvider.notifier)
            .syncTrack(track: widget.track),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publishedContentSyncControllerProvider);
    final snapshotAsync = ref.watch(
      publishedContentSyncSnapshotProvider(widget.track),
    );
    final count = snapshotAsync.valueOrNull?.activeItemCount ?? 0;
    final statusLabel = switch (state.status) {
      PublishedContentSyncStatus.idle => 'idle',
      PublishedContentSyncStatus.syncing => 'syncing',
      PublishedContentSyncStatus.success => 'success',
      PublishedContentSyncStatus.error => 'error',
    };
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text('status:$statusLabel'),
          Text('count:$count'),
        ],
      ),
    );
  }
}
