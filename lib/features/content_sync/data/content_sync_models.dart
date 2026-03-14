import '../../../core/database/converters/json_models.dart';

class ContentSyncException implements Exception {
  const ContentSyncException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  bool get isServerUnavailable =>
      statusCode != null && (statusCode! >= 500 || statusCode == 429);

  @override
  String toString() => 'ContentSyncException($code, $statusCode): $message';
}

class PublicContentSyncUpsert {
  const PublicContentSyncUpsert({
    required this.unitId,
    required this.revisionId,
    required this.track,
    required this.skill,
    required this.typeTag,
    required this.difficulty,
    required this.publishedAt,
    required this.hasAudio,
  });

  final String unitId;
  final String revisionId;
  final String track;
  final String skill;
  final String typeTag;
  final int difficulty;
  final DateTime publishedAt;
  final bool hasAudio;

  factory PublicContentSyncUpsert.fromJson(JsonMap json) {
    return PublicContentSyncUpsert(
      unitId: readRequiredString(json, 'unitId', path: 'upsert.unitId'),
      revisionId: readRequiredString(
        json,
        'revisionId',
        path: 'upsert.revisionId',
      ),
      track: readRequiredString(json, 'track', path: 'upsert.track'),
      skill: readRequiredString(json, 'skill', path: 'upsert.skill'),
      typeTag: readRequiredString(json, 'typeTag', path: 'upsert.typeTag'),
      difficulty: _readRequiredInt(json, 'difficulty', path: 'upsert.difficulty'),
      publishedAt: _readRequiredDateTime(
        json,
        'publishedAt',
        path: 'upsert.publishedAt',
      ),
      hasAudio: _readRequiredBool(json, 'hasAudio', path: 'upsert.hasAudio'),
    );
  }
}

class PublicContentSyncDelete {
  const PublicContentSyncDelete({
    required this.unitId,
    required this.revisionId,
    required this.reason,
    required this.changedAt,
  });

  final String unitId;
  final String revisionId;
  final String reason;
  final DateTime changedAt;

  factory PublicContentSyncDelete.fromJson(JsonMap json) {
    return PublicContentSyncDelete(
      unitId: readRequiredString(json, 'unitId', path: 'delete.unitId'),
      revisionId: readRequiredString(
        json,
        'revisionId',
        path: 'delete.revisionId',
      ),
      reason: readRequiredString(json, 'reason', path: 'delete.reason'),
      changedAt: _readRequiredDateTime(
        json,
        'changedAt',
        path: 'delete.changedAt',
      ),
    );
  }
}

class PublicContentSyncPage {
  const PublicContentSyncPage({
    required this.upserts,
    required this.deletes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PublicContentSyncUpsert> upserts;
  final List<PublicContentSyncDelete> deletes;
  final String? nextCursor;
  final bool hasMore;

  factory PublicContentSyncPage.fromJson(JsonMap json) {
    return PublicContentSyncPage(
      upserts: _readObjectList(
        json,
        'upserts',
        path: 'syncPage.upserts',
      ).map(PublicContentSyncUpsert.fromJson).toList(growable: false),
      deletes: _readObjectList(
        json,
        'deletes',
        path: 'syncPage.deletes',
      ).map(PublicContentSyncDelete.fromJson).toList(growable: false),
      nextCursor: _readOptionalString(
        json,
        'nextCursor',
        path: 'syncPage.nextCursor',
      ),
      hasMore: _readRequiredBool(json, 'hasMore', path: 'syncPage.hasMore'),
    );
  }
}

class PublishedContentAssetPayload {
  const PublishedContentAssetPayload({
    required this.assetId,
    required this.mimeType,
    required this.signedUrl,
    required this.expiresInSeconds,
  });

  final String assetId;
  final String mimeType;
  final String signedUrl;
  final int expiresInSeconds;

  factory PublishedContentAssetPayload.fromJson(JsonMap json) {
    return PublishedContentAssetPayload(
      assetId: readRequiredString(json, 'assetId', path: 'asset.assetId'),
      mimeType: readRequiredString(json, 'mimeType', path: 'asset.mimeType'),
      signedUrl: readRequiredString(json, 'signedUrl', path: 'asset.signedUrl'),
      expiresInSeconds: _readRequiredInt(
        json,
        'expiresInSeconds',
        path: 'asset.expiresInSeconds',
      ),
    );
  }
}

class PublishedContentQuestionPayload {
  const PublishedContentQuestionPayload({
    required this.stem,
    required this.options,
    required this.answerKey,
    required this.evidenceSentenceIds,
    required this.whyCorrectKo,
    required this.whyWrongKoByOption,
    this.explanation,
    this.vocabNotesKo,
    this.structureNotesKo,
  });

  final String stem;
  final Map<String, String> options;
  final String answerKey;
  final List<String> evidenceSentenceIds;
  final String whyCorrectKo;
  final Map<String, String> whyWrongKoByOption;
  final String? explanation;
  final String? vocabNotesKo;
  final String? structureNotesKo;

  factory PublishedContentQuestionPayload.fromJson(JsonMap json) {
    return PublishedContentQuestionPayload(
      stem: readRequiredString(json, 'stem', path: 'question.stem'),
      options: _readRequiredStringMap(json, 'options', path: 'question.options'),
      answerKey: readRequiredString(
        json,
        'answerKey',
        path: 'question.answerKey',
      ),
      evidenceSentenceIds: readStringList(
        json,
        'evidenceSentenceIds',
        path: 'question.evidenceSentenceIds',
      ),
      whyCorrectKo: readRequiredString(
        json,
        'whyCorrectKo',
        path: 'question.whyCorrectKo',
      ),
      whyWrongKoByOption: _readRequiredStringMap(
        json,
        'whyWrongKoByOption',
        path: 'question.whyWrongKoByOption',
      ),
      explanation: _readOptionalString(
        json,
        'explanation',
        path: 'question.explanation',
      ),
      vocabNotesKo: _readOptionalString(
        json,
        'vocabNotesKo',
        path: 'question.vocabNotesKo',
      ),
      structureNotesKo: _readOptionalString(
        json,
        'structureNotesKo',
        path: 'question.structureNotesKo',
      ),
    );
  }
}

class PublishedContentDetailPayload {
  const PublishedContentDetailPayload({
    required this.unitId,
    required this.revisionId,
    required this.track,
    required this.skill,
    required this.typeTag,
    required this.difficulty,
    required this.publishedAt,
    required this.contentSourcePolicy,
    required this.question,
    this.bodyText,
    this.transcriptText,
    this.ttsPlan,
    this.asset,
  });

  final String unitId;
  final String revisionId;
  final String track;
  final String skill;
  final String typeTag;
  final int difficulty;
  final DateTime publishedAt;
  final String contentSourcePolicy;
  final String? bodyText;
  final String? transcriptText;
  final JsonMap? ttsPlan;
  final PublishedContentAssetPayload? asset;
  final PublishedContentQuestionPayload question;

  factory PublishedContentDetailPayload.fromJson(JsonMap json) {
    final assetJson = _readOptionalMap(json, 'asset', path: 'detail.asset');
    return PublishedContentDetailPayload(
      unitId: readRequiredString(json, 'unitId', path: 'detail.unitId'),
      revisionId: readRequiredString(
        json,
        'revisionId',
        path: 'detail.revisionId',
      ),
      track: readRequiredString(json, 'track', path: 'detail.track'),
      skill: readRequiredString(json, 'skill', path: 'detail.skill'),
      typeTag: readRequiredString(json, 'typeTag', path: 'detail.typeTag'),
      difficulty: _readRequiredInt(json, 'difficulty', path: 'detail.difficulty'),
      publishedAt: _readRequiredDateTime(
        json,
        'publishedAt',
        path: 'detail.publishedAt',
      ),
      contentSourcePolicy: readRequiredString(
        json,
        'contentSourcePolicy',
        path: 'detail.contentSourcePolicy',
      ),
      bodyText: _readOptionalString(json, 'bodyText', path: 'detail.bodyText'),
      transcriptText: _readOptionalString(
        json,
        'transcriptText',
        path: 'detail.transcriptText',
      ),
      ttsPlan: _readOptionalMap(json, 'ttsPlan', path: 'detail.ttsPlan'),
      asset: assetJson == null ? null : PublishedContentAssetPayload.fromJson(assetJson),
      question: PublishedContentQuestionPayload.fromJson(
        readRequiredMap(json, 'question', path: 'detail.question'),
      ),
    );
  }
}

class PublishedContentSyncSnapshot {
  const PublishedContentSyncSnapshot({
    required this.track,
    required this.activeItemCount,
    this.lastSyncCursor,
    this.lastSyncAtUtc,
    this.syncInProgress = false,
    this.lastSyncErrorCode,
  });

  final String track;
  final int activeItemCount;
  final String? lastSyncCursor;
  final DateTime? lastSyncAtUtc;
  final bool syncInProgress;
  final String? lastSyncErrorCode;
}

class PublishedContentSyncResult {
  const PublishedContentSyncResult({
    required this.track,
    required this.pagesFetched,
    required this.upserted,
    required this.deleted,
    required this.activeItemCount,
    this.lastCursor,
    this.lastSyncAtUtc,
  });

  final String track;
  final int pagesFetched;
  final int upserted;
  final int deleted;
  final int activeItemCount;
  final String? lastCursor;
  final DateTime? lastSyncAtUtc;
}

List<JsonMap> _readObjectList(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$path" to be a list.');
  }
  return value.map((Object? item) {
    if (item is JsonMap) {
      return item;
    }
    if (item is Map) {
      return Map<String, Object?>.from(item);
    }
    throw FormatException('Expected "$path" items to be objects.');
  }).toList(growable: false);
}

Map<String, String> _readRequiredStringMap(
  JsonMap json,
  String key, {
  required String path,
}) {
  final raw = readRequiredMap(json, key, path: path);
  final result = <String, String>{};
  for (final MapEntry<String, Object?> entry in raw.entries) {
    final value = entry.value;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Expected "$path.${entry.key}" to be a string.');
    }
    result[entry.key] = value;
  }
  return result;
}

String? _readOptionalString(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  throw FormatException('Expected "$path" to be a string.');
}

JsonMap? _readOptionalMap(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is JsonMap) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw FormatException('Expected "$path" to be an object.');
}

int _readRequiredInt(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected "$path" to be an integer.');
}

bool _readRequiredBool(JsonMap json, String key, {required String path}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected "$path" to be a boolean.');
}

DateTime _readRequiredDateTime(JsonMap json, String key, {required String path}) {
  final raw = readRequiredString(json, key, path: path);
  return DateTime.parse(raw).toUtc();
}
