import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_repository.dart';

enum FamilyLinksRole { parent, student }

class FamilyLinkCode {
  const FamilyLinkCode({
    required this.code,
    required this.expiresAt,
    required this.activeParentCount,
    required this.maxParentsPerChild,
  });

  final String code;
  final DateTime expiresAt;
  final int activeParentCount;
  final int maxParentsPerChild;
}

class FamilyLinkedUserSummary {
  const FamilyLinkedUserSummary({
    required this.id,
    required this.email,
    required this.linkedAt,
  });

  final String id;
  final String email;
  final DateTime linkedAt;
}

class FamilyLinksSnapshot {
  const FamilyLinksSnapshot({
    required this.role,
    required this.linkedChildren,
    required this.linkedParents,
    required this.activeChildCount,
    required this.activeParentCount,
    required this.maxChildrenPerParent,
    required this.maxParentsPerChild,
  });

  final FamilyLinksRole role;
  final List<FamilyLinkedUserSummary> linkedChildren;
  final List<FamilyLinkedUserSummary> linkedParents;
  final int activeChildCount;
  final int activeParentCount;
  final int maxChildrenPerParent;
  final int maxParentsPerChild;
}

class FamilyLinkConsumeResult {
  const FamilyLinkConsumeResult({
    required this.parentId,
    required this.childId,
    required this.linkedAt,
  });

  final String parentId;
  final String childId;
  final DateTime linkedAt;
}

class FamilyRepositoryException implements Exception {
  const FamilyRepositoryException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'FamilyRepositoryException($code, $statusCode): $message';
}

class FamilyRepository {
  FamilyRepository({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  Future<FamilyLinkCode> createChildLinkCode() async {
    final response = await _authRepository.authorizedPost('/family/link-codes');
    final body = _requireSuccessBody(response);
    return FamilyLinkCode(
      code: _requiredString(body, 'code'),
      expiresAt: _requiredDateTime(body, 'expires_at'),
      activeParentCount: _requiredInt(body, 'active_parent_count'),
      maxParentsPerChild: _requiredInt(body, 'max_parents_per_child'),
    );
  }

  Future<FamilyLinkConsumeResult> consumeChildLinkCode(String code) async {
    final normalizedCode = code.trim();
    final response = await _authRepository.authorizedPost(
      '/family/link-codes/consume',
      body: <String, Object?>{'code': normalizedCode},
    );
    final body = _requireSuccessBody(response);
    return FamilyLinkConsumeResult(
      parentId: _requiredString(body, 'parent_id'),
      childId: _requiredString(body, 'child_id'),
      linkedAt: _requiredDateTime(body, 'linked_at'),
    );
  }

  Future<FamilyLinksSnapshot> loadFamilyLinks() async {
    final response = await _authRepository.authorizedGet('/family/links');
    final body = _requireSuccessBody(response);
    return FamilyLinksSnapshot(
      role: _parseRole(_requiredString(body, 'role')),
      linkedChildren: _parseLinkedUsers(body['linked_children']),
      linkedParents: _parseLinkedUsers(body['linked_parents']),
      activeChildCount: _requiredInt(body, 'active_child_count'),
      activeParentCount: _requiredInt(body, 'active_parent_count'),
      maxChildrenPerParent: _requiredInt(body, 'max_children_per_parent'),
      maxParentsPerChild: _requiredInt(body, 'max_parents_per_child'),
    );
  }

  Map<String, Object?> _requireSuccessBody(JsonApiResponse response) {
    if (response.statusCode >= 400) {
      throw _toException(response);
    }
    final body = response.bodyAsMap;
    if (body.isEmpty) {
      throw FamilyRepositoryException(
        code: 'invalid_response',
        message: 'The server returned an empty response body.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  FamilyRepositoryException _toException(JsonApiResponse response) {
    final body = response.bodyAsMap;
    final code =
        body['errorCode']?.toString() ??
        body['detail']?.toString() ??
        'http_${response.statusCode}';
    final message = body['detail']?.toString() ?? 'Request failed.';
    return FamilyRepositoryException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  FamilyLinksRole _parseRole(String role) {
    switch (role) {
      case 'PARENT':
        return FamilyLinksRole.parent;
      case 'STUDENT':
        return FamilyLinksRole.student;
    }
    throw const FamilyRepositoryException(
      code: 'invalid_response',
      message: 'Unknown family links role.',
    );
  }

  List<FamilyLinkedUserSummary> _parseLinkedUsers(Object? rawValue) {
    if (rawValue is! List) {
      return const <FamilyLinkedUserSummary>[];
    }
    return rawValue
        .map((Object? item) {
          if (item is! Map) {
            throw const FamilyRepositoryException(
              code: 'invalid_response',
              message: 'Linked family member must be an object.',
            );
          }
          final map = Map<String, Object?>.from(item as Map<Object?, Object?>);
          return FamilyLinkedUserSummary(
            id: _requiredString(map, 'id'),
            email: _requiredString(map, 'email'),
            linkedAt: _requiredDateTime(map, 'linked_at'),
          );
        })
        .toList(growable: false);
  }

  String _requiredString(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FamilyRepositoryException(
      code: 'invalid_response',
      message: 'Missing required string field: $key',
    );
  }

  int _requiredInt(Map<String, Object?> body, String key) {
    final value = body[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FamilyRepositoryException(
      code: 'invalid_response',
      message: 'Missing required integer field: $key',
    );
  }

  DateTime _requiredDateTime(Map<String, Object?> body, String key) {
    final raw = _requiredString(body, key);
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      throw FamilyRepositoryException(
        code: 'invalid_response',
        message: 'Invalid datetime field: $key',
      );
    }
  }
}

@visibleForTesting
FamilyLinkedUserSummary familyLinkedUser({
  required String id,
  required String email,
  required DateTime linkedAt,
}) {
  return FamilyLinkedUserSummary(id: id, email: email, linkedAt: linkedAt);
}
