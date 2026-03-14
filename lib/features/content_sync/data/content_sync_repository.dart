import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/converters/json_models.dart';
import '../../../core/network/api_client.dart';
import 'content_sync_models.dart';

const String publishedContentPackId = 'backend-published-sync';
const String publishedContentPackTitle = 'Synced published content';
const int _defaultContentSyncPageSize = 50;

class PublishedContentSyncRepository {
  PublishedContentSyncRepository({
    required AppDatabase database,
    required JsonApiClient apiClient,
  }) : _database = database,
       _apiClient = apiClient;

  final AppDatabase _database;
  final JsonApiClient _apiClient;

  Future<PublishedContentSyncSnapshot> getSnapshot({required String track}) async {
    final row = await (_database.select(
      _database.publishedContentSyncStates,
    )..where((tbl) => tbl.track.equals(track))).getSingleOrNull();
    final activeItemCount = await _countActiveItems(track: track);
    if (row == null) {
      return PublishedContentSyncSnapshot(
        track: track,
        activeItemCount: activeItemCount,
      );
    }
    return PublishedContentSyncSnapshot(
      track: row.track,
      activeItemCount: activeItemCount,
      lastSyncCursor: row.lastSyncCursor,
      lastSyncAtUtc: row.lastSyncAtUtc,
      syncInProgress: row.syncInProgress,
      lastSyncErrorCode: row.lastSyncErrorCode,
    );
  }

  Future<int> countActiveItems({required String track}) {
    return _countActiveItems(track: track);
  }

  Future<PublishedContentSyncResult> syncTrack({required String track}) async {
    await _ensurePublishedContentPack();
    final initialSnapshot = await getSnapshot(track: track);
    await _writeSyncState(
      track: track,
      lastSyncCursor: initialSnapshot.lastSyncCursor,
      lastSyncAtUtc: initialSnapshot.lastSyncAtUtc,
      syncInProgress: true,
      lastSyncErrorCode: null,
    );

    var cursor = initialSnapshot.lastSyncCursor;
    var pagesFetched = 0;
    var upserted = 0;
    var deleted = 0;

    try {
      while (true) {
        final page = await _fetchSyncPage(track: track, cursor: cursor);
        pagesFetched += 1;

        for (final PublicContentSyncUpsert item in page.upserts) {
          final detail = await _fetchDetail(revisionId: item.revisionId);
          await _applyUpsert(item: item, detail: detail);
          upserted += 1;
        }
        for (final PublicContentSyncDelete item in page.deletes) {
          await _applyDelete(item);
          deleted += 1;
        }

        if (!page.hasMore) {
          if (page.nextCursor != null) {
            cursor = page.nextCursor;
          }
          break;
        }
        if (page.nextCursor == null) {
          throw const ContentSyncException(
            code: 'invalid_response',
            message: 'Missing nextCursor for paginated sync response.',
          );
        }
        cursor = page.nextCursor;
      }

      final syncedAt = DateTime.now().toUtc();
      await _writeSyncState(
        track: track,
        lastSyncCursor: cursor,
        lastSyncAtUtc: syncedAt,
        syncInProgress: false,
        lastSyncErrorCode: null,
      );
      final activeItemCount = await _countActiveItems(track: track);
      return PublishedContentSyncResult(
        track: track,
        pagesFetched: pagesFetched,
        upserted: upserted,
        deleted: deleted,
        activeItemCount: activeItemCount,
        lastCursor: cursor,
        lastSyncAtUtc: syncedAt,
      );
    } on ContentSyncException catch (error) {
      await _writeSyncState(
        track: track,
        lastSyncCursor: initialSnapshot.lastSyncCursor,
        lastSyncAtUtc: initialSnapshot.lastSyncAtUtc,
        syncInProgress: false,
        lastSyncErrorCode: error.code,
      );
      rethrow;
    } on FormatException catch (error) {
      await _writeSyncState(
        track: track,
        lastSyncCursor: initialSnapshot.lastSyncCursor,
        lastSyncAtUtc: initialSnapshot.lastSyncAtUtc,
        syncInProgress: false,
        lastSyncErrorCode: 'invalid_response',
      );
      throw ContentSyncException(
        code: 'invalid_response',
        message: error.message,
      );
    }
  }

  Future<PublishedContentAssetPayload?> fetchListeningAssetLease({
    required String revisionId,
  }) async {
    final detail = await _fetchDetail(revisionId: revisionId);
    return detail.asset;
  }

  Future<void> _ensurePublishedContentPack() async {
    await _database.into(_database.contentPacks).insertOnConflictUpdate(
      ContentPacksCompanion(
        id: const Value(publishedContentPackId),
        version: const Value(1),
        locale: const Value('en-US'),
        title: const Value(publishedContentPackTitle),
        description: const Value(
          'Published content synchronized from the backend.',
        ),
        checksum: const Value('published-content-sync-v1'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<PublicContentSyncPage> _fetchSyncPage({
    required String track,
    required String? cursor,
  }) async {
    final query = <String, String>{
      'track': track,
      'pageSize': _defaultContentSyncPageSize.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
    };
    try {
      final response = await _apiClient.get(
        '/public/content/sync?${Uri(queryParameters: query).query}',
      );
      final body = _requireSuccessBody(response);
      return PublicContentSyncPage.fromJson(body);
    } on ContentSyncException {
      rethrow;
    } on Object catch (error) {
      throw ContentSyncException(
        code: 'content_sync_transport_failed',
        message: error.toString(),
      );
    }
  }

  Future<PublishedContentDetailPayload> _fetchDetail({
    required String revisionId,
  }) async {
    try {
      final response = await _apiClient.get('/public/content/units/$revisionId');
      final body = _requireSuccessBody(response);
      return PublishedContentDetailPayload.fromJson(body);
    } on ContentSyncException {
      rethrow;
    } on Object catch (error) {
      throw ContentSyncException(
        code: 'content_sync_transport_failed',
        message: error.toString(),
      );
    }
  }

  Map<String, Object?> _requireSuccessBody(JsonApiResponse response) {
    if (response.statusCode >= 400) {
      final body = response.bodyAsMap;
      throw ContentSyncException(
        code: body['errorCode']?.toString() ??
            body['detail']?.toString() ??
            'http_${response.statusCode}',
        message: body['detail']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }
    final body = response.bodyAsMap;
    if (body.isEmpty) {
      throw const ContentSyncException(
        code: 'invalid_response',
        message: 'The server returned an empty response body.',
      );
    }
    return body;
  }

  Future<void> _applyUpsert({
    required PublicContentSyncUpsert item,
    required PublishedContentDetailPayload detail,
  }) async {
    if (detail.skill != item.skill ||
        detail.track != item.track ||
        detail.typeTag != item.typeTag ||
        detail.difficulty != item.difficulty) {
      throw const ContentSyncException(
        code: 'invalid_response',
        message: 'Sync summary and detail payloads disagree.',
      );
    }

    final revisionKey = detail.revisionId;
    final questionId = 'remote:question:$revisionKey';
    final explanationId = 'remote:explanation:$revisionKey';
    final passageId = detail.skill == 'READING' ? 'remote:passage:$revisionKey' : null;
    final scriptId = detail.skill == 'LISTENING' ? 'remote:script:$revisionKey' : null;
    final now = DateTime.now().toUtc();
    final parsedQuestion = detail.question;
    final sentences = _buildSentences(
      skill: detail.skill,
      bodyText: detail.bodyText,
      transcriptText: detail.transcriptText,
      evidenceSentenceIds: parsedQuestion.evidenceSentenceIds,
    );

    await _database.transaction(() async {
      await (_database.update(_database.publishedContentCacheEntries)
            ..where((tbl) => tbl.unitId.equals(detail.unitId)))
          .write(
            PublishedContentCacheEntriesCompanion(
              isActive: const Value(false),
              syncedAt: Value(now),
            ),
          );

      if (detail.skill == 'READING') {
        await _database.into(_database.passages).insertOnConflictUpdate(
          PassagesCompanion(
            id: Value(passageId!),
            packId: const Value(publishedContentPackId),
            title: Value(_buildPassageTitle(detail)),
            sentencesJson: Value(sentences),
            orderIndex: const Value(0),
          ),
        );
      } else {
        final listeningSource = _buildListeningSource(
          transcriptText: detail.transcriptText,
          evidenceSentenceIds: parsedQuestion.evidenceSentenceIds,
        );
        await _database.into(_database.scripts).insertOnConflictUpdate(
          ScriptsCompanion(
            id: Value(scriptId!),
            packId: const Value(publishedContentPackId),
            sentencesJson: Value(listeningSource.sentences),
            turnsJson: Value(listeningSource.turns),
            ttsPlanJson: Value(_resolveTtsPlan(detail.ttsPlan)),
            orderIndex: const Value(0),
          ),
        );
      }

      await _database.into(_database.questions).insertOnConflictUpdate(
        QuestionsCompanion(
          id: Value(questionId),
          skill: Value(detail.skill),
          typeTag: Value(detail.typeTag),
          track: Value(detail.track),
          difficulty: Value(detail.difficulty),
          passageId: Value(passageId),
          scriptId: Value(scriptId),
          prompt: Value(parsedQuestion.stem),
          optionsJson: Value(
            OptionMap.fromJson(
              _toExactOptionMapJson(parsedQuestion.options),
              path: 'detail.question.options',
            ),
          ),
          answerKey: Value(parsedQuestion.answerKey),
          orderIndex: const Value(0),
        ),
      );

      await _database.into(_database.explanations).insertOnConflictUpdate(
        ExplanationsCompanion(
          id: Value(explanationId),
          questionId: Value(questionId),
          evidenceSentenceIdsJson: Value(parsedQuestion.evidenceSentenceIds),
          whyCorrectKo: Value(parsedQuestion.whyCorrectKo),
          whyWrongKoJson: Value(
            OptionMap.fromJson(
              _toExactOptionMapJson(
                parsedQuestion.whyWrongKoByOption,
                fillMissingWithEmpty: true,
              ),
              path: 'detail.question.whyWrongKoByOption',
            ),
          ),
          vocabNotesJson: Value(
            _encodeNullableJson(parsedQuestion.vocabNotesKo),
          ),
          structureNotesKo: Value(parsedQuestion.structureNotesKo),
          glossKoJson: const Value(null),
        ),
      );

      await _database
          .into(_database.publishedContentCacheEntries)
          .insertOnConflictUpdate(
            PublishedContentCacheEntriesCompanion(
              revisionId: Value(detail.revisionId),
              unitId: Value(detail.unitId),
              questionId: Value(questionId),
              explanationId: Value(explanationId),
              passageId: Value(passageId),
              scriptId: Value(scriptId),
              track: Value(detail.track),
              skill: Value(detail.skill),
              typeTag: Value(detail.typeTag),
              difficulty: Value(detail.difficulty),
              contentSourcePolicy: Value(detail.contentSourcePolicy),
              hasAudio: Value(item.hasAudio),
              assetId: Value(detail.asset?.assetId),
              assetMimeType: Value(detail.asset?.mimeType),
              isActive: const Value(true),
              publishedAt: Value(detail.publishedAt),
              syncedAt: Value(now),
            ),
          );
    });
  }

  Future<void> _applyDelete(PublicContentSyncDelete item) async {
    final now = DateTime.now().toUtc();
    await (_database.update(_database.publishedContentCacheEntries)
          ..where((tbl) =>
              tbl.revisionId.equals(item.revisionId) & tbl.unitId.equals(item.unitId)))
        .write(
          PublishedContentCacheEntriesCompanion(
            isActive: const Value(false),
            syncedAt: Value(now),
          ),
        );
  }

  Future<void> _writeSyncState({
    required String track,
    required String? lastSyncCursor,
    required DateTime? lastSyncAtUtc,
    required bool syncInProgress,
    required String? lastSyncErrorCode,
  }) {
    return _database.into(_database.publishedContentSyncStates).insertOnConflictUpdate(
      PublishedContentSyncStatesCompanion(
        track: Value(track),
        lastSyncCursor: Value(lastSyncCursor),
        lastSyncAtUtc: Value(lastSyncAtUtc),
        syncInProgress: Value(syncInProgress),
        lastSyncErrorCode: Value(lastSyncErrorCode),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<int> _countActiveItems({required String track}) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS row_count '
          'FROM published_content_cache_entries '
          'WHERE track = ? AND is_active = 1',
          variables: <Variable<Object>>[Variable<String>(track)],
          readsFrom: {_database.publishedContentCacheEntries},
        )
        .getSingle();
    return row.read<int>('row_count');
  }

  String _buildPassageTitle(PublishedContentDetailPayload detail) {
    return '${detail.track} ${detail.typeTag}';
  }

  List<Sentence> _buildSentences({
    required String skill,
    required String? bodyText,
    required String? transcriptText,
    required List<String> evidenceSentenceIds,
  }) {
    final sourceText = skill == 'READING' ? bodyText : transcriptText;
    final normalized = (sourceText ?? '').trim();
    if (normalized.isEmpty) {
      throw const ContentSyncException(
        code: 'invalid_response',
        message: 'Published content detail is missing source text.',
      );
    }
    final segments = _splitSentences(
      normalized,
      minimumCount: _extractMinimumSentenceCount(evidenceSentenceIds),
    );
    return <Sentence>[
      for (var index = 0; index < segments.length; index++)
        Sentence(id: 's${index + 1}', text: segments[index]),
    ];
  }

  _ListeningSource _buildListeningSource({
    required String? transcriptText,
    required List<String> evidenceSentenceIds,
  }) {
    final normalized = (transcriptText ?? '').trim();
    if (normalized.isEmpty) {
      throw const ContentSyncException(
        code: 'invalid_response',
        message: 'Listening content detail is missing transcript text.',
      );
    }

    final rawTurns = _splitTranscriptTurns(normalized);
    final minimumCount = _extractMinimumSentenceCount(evidenceSentenceIds);
    final sentences = <Sentence>[];
    final turns = <Turn>[];
    final speakerRoleMap = <String, String>{};

    for (final _TranscriptTurn rawTurn in rawTurns) {
      final role = _mapSpeakerRole(
        rawSpeaker: rawTurn.speaker,
        speakerRoleMap: speakerRoleMap,
      );
      final parts = _splitSentences(rawTurn.text, minimumCount: 1);
      final sentenceIds = <String>[];
      for (final String part in parts) {
        final sentenceId = 's${sentences.length + 1}';
        sentences.add(Sentence(id: sentenceId, text: part));
        sentenceIds.add(sentenceId);
      }
      turns.add(Turn(speaker: role, sentenceIds: sentenceIds));
    }

    while (sentences.length < minimumCount) {
      final fallbackId = 's${sentences.length + 1}';
      final fallbackText = sentences.isEmpty ? normalized : sentences.last.text;
      sentences.add(Sentence(id: fallbackId, text: fallbackText));
      if (turns.isEmpty) {
        turns.add(Turn(speaker: 'N', sentenceIds: <String>[fallbackId]));
      } else {
        final lastTurn = turns.removeLast();
        turns.add(
          Turn(
            speaker: lastTurn.speaker,
            sentenceIds: <String>[...lastTurn.sentenceIds, fallbackId],
          ),
        );
      }
    }

    return _ListeningSource(sentences: sentences, turns: turns);
  }

  TtsPlan _resolveTtsPlan(JsonMap? rawPlan) {
    if (rawPlan != null) {
      try {
        return TtsPlan.fromJson(rawPlan, path: 'detail.ttsPlan');
      } on FormatException {
        // Fall back to a safe local plan for synced content.
      }
    }
    return const TtsPlan(
      repeatPolicy: <String, Object?>{'type': 'single'},
      pauseRangeMs: NumericRange(min: 150, max: 350),
      rateRange: NumericRange(min: 0.95, max: 1.0),
      pitchRange: NumericRange(min: -1.0, max: 1.0),
      voiceRoles: <String, String>{
        'S1': 'alloy',
        'S2': 'nova',
        'N': 'alloy',
      },
    );
  }

  List<String> _splitSentences(String text, {required int minimumCount}) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final primary = normalized
        .split(RegExp(r'\n+'))
        .expand((String line) => line.split(RegExp(r'(?<=[.!?])\s+')))
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (primary.length >= minimumCount) {
      return primary;
    }

    final secondary = normalized
        .split(RegExp(r'(?<=[.!?;,])\s+'))
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (secondary.length >= minimumCount || secondary.length > primary.length) {
      return secondary;
    }
    return primary.isEmpty ? <String>[normalized] : primary;
  }

  List<_TranscriptTurn> _splitTranscriptTurns(String transcriptText) {
    final normalized = transcriptText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    final speakerPattern = RegExp(
      r'([A-Za-z][A-Za-z ]{0,30}):\s*([^\n]+?)(?=(?:\n|$|[A-Za-z][A-Za-z ]{0,30}:\s*))',
      multiLine: true,
    );
    final matches = speakerPattern.allMatches(normalized).toList(growable: false);
    if (matches.length >= 2) {
      return matches.map((Match match) {
        return _TranscriptTurn(
          speaker: match.group(1)!.trim(),
          text: match.group(2)!.trim(),
        );
      }).toList(growable: false);
    }

    final lines = normalized
        .split(RegExp(r'\n+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return <_TranscriptTurn>[_TranscriptTurn(speaker: null, text: normalized)];
    }

    return lines.map((String line) {
      final colonIndex = line.indexOf(':');
      if (colonIndex > 0 && colonIndex < 32) {
        final speaker = line.substring(0, colonIndex).trim();
        final text = line.substring(colonIndex + 1).trim();
        if (speaker.isNotEmpty && text.isNotEmpty) {
          return _TranscriptTurn(speaker: speaker, text: text);
        }
      }
      return _TranscriptTurn(speaker: null, text: line);
    }).toList(growable: false);
  }

  String _mapSpeakerRole({
    required String? rawSpeaker,
    required Map<String, String> speakerRoleMap,
  }) {
    final normalized = rawSpeaker?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'N';
    }
    final existing = speakerRoleMap[normalized];
    if (existing != null) {
      return existing;
    }
    final assigned = switch (speakerRoleMap.length) {
      0 => 'S1',
      1 => 'S2',
      _ => 'N',
    };
    speakerRoleMap[normalized] = assigned;
    return assigned;
  }

  int _extractMinimumSentenceCount(List<String> evidenceSentenceIds) {
    var maxIndex = 1;
    for (final String value in evidenceSentenceIds) {
      final match = RegExp(r'^s(\d+)$').firstMatch(value.trim());
      if (match == null) {
        continue;
      }
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > maxIndex) {
        maxIndex = parsed;
      }
    }
    return maxIndex;
  }

  String? _encodeNullableJson(Object? value) {
    if (value == null) {
      return null;
    }
    return jsonEncode(value);
  }

  Map<String, Object?> _toExactOptionMapJson(
    Map<String, String> raw, {
    bool fillMissingWithEmpty = false,
  }) {
    const keys = <String>['A', 'B', 'C', 'D', 'E'];
    final result = <String, Object?>{};
    for (final key in keys) {
      final value = raw[key];
      if (value == null) {
        if (!fillMissingWithEmpty) {
          throw const ContentSyncException(
            code: 'invalid_response',
            message: 'Question options must include A..E.',
          );
        }
        result[key] = '';
        continue;
      }
      result[key] = value;
    }
    return result;
  }
}

class _TranscriptTurn {
  const _TranscriptTurn({required this.speaker, required this.text});

  final String? speaker;
  final String text;
}

class _ListeningSource {
  const _ListeningSource({required this.sentences, required this.turns});

  final List<Sentence> sentences;
  final List<Turn> turns;
}
