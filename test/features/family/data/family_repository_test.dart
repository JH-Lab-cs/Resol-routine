import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/network/api_client.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/auth/data/auth_repository.dart';
import 'package:resol_routine/features/family/data/family_repository.dart';

void main() {
  group('FamilyRepository', () {
    test('student code issue success parses code payload', () async {
      final repository = FamilyRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedPost: (String path, Object? body) async {
            expect(path, '/family/link-codes');
            expect(body, isNull);
            return _jsonResponse(200, <String, Object?>{
              'code': '654321',
              'expires_at': '2026-03-13T12:10:00Z',
              'active_parent_count': 1,
              'max_parents_per_child': 2,
            });
          },
        ),
      );

      final result = await repository.createChildLinkCode();

      expect(result.code, '654321');
      expect(result.activeParentCount, 1);
      expect(result.maxParentsPerChild, 2);
    });

    test('parent consume success parses linked child payload', () async {
      final repository = FamilyRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedPost: (String path, Object? body) async {
            expect(path, '/family/link-codes/consume');
            expect(body, <String, Object?>{'code': '654321'});
            return _jsonResponse(200, <String, Object?>{
              'parent_id': 'parent-1',
              'child_id': 'child-1',
              'linked_at': '2026-03-13T12:20:00Z',
            });
          },
        ),
      );

      final result = await repository.consumeChildLinkCode(' 654321 ');

      expect(result.parentId, 'parent-1');
      expect(result.childId, 'child-1');
    });

    test('consume maps structured backend errors', () async {
      final repository = FamilyRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedPost: (String path, Object? body) async {
            return _jsonResponse(410, <String, Object?>{
              'detail': 'link_code_expired',
              'errorCode': 'link_code_expired',
            });
          },
        ),
      );

      await expectLater(
        repository.consumeChildLinkCode('654321'),
        throwsA(
          isA<FamilyRepositoryException>()
              .having((error) => error.code, 'code', 'link_code_expired')
              .having((error) => error.statusCode, 'statusCode', 410),
        ),
      );
    });

    test('loadFamilyLinks parses parent snapshot', () async {
      final repository = FamilyRepository(
        authRepository: _FakeAuthRepository(
          onAuthorizedGet: (String path) async {
            expect(path, '/family/links');
            return _jsonResponse(200, <String, Object?>{
              'role': 'PARENT',
              'linked_children': <Object?>[
                <String, Object?>{
                  'id': 'child-1',
                  'email': 'chulsoo@example.com',
                  'linked_at': '2026-03-13T12:20:00Z',
                },
              ],
              'linked_parents': <Object?>[],
              'active_child_count': 1,
              'active_parent_count': 0,
              'max_children_per_parent': 5,
              'max_parents_per_child': 2,
            });
          },
        ),
      );

      final snapshot = await repository.loadFamilyLinks();

      expect(snapshot.role, FamilyLinksRole.parent);
      expect(snapshot.linkedChildren, hasLength(1));
      expect(snapshot.linkedChildren.first.email, 'chulsoo@example.com');
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.onAuthorizedGet, this.onAuthorizedPost});

  final Future<JsonApiResponse> Function(String path)? onAuthorizedGet;
  final Future<JsonApiResponse> Function(String path, Object? body)?
  onAuthorizedPost;

  @override
  Future<JsonApiResponse> authorizedGet(
    String path, {
    bool retryOnUnauthorized = true,
  }) {
    final handler = onAuthorizedGet;
    if (handler == null) {
      throw UnimplementedError(
        'authorizedGet was not configured for this test.',
      );
    }
    return handler(path);
  }

  @override
  Future<JsonApiResponse> authorizedPost(
    String path, {
    Object? body,
    bool retryOnUnauthorized = true,
  }) {
    final handler = onAuthorizedPost;
    if (handler == null) {
      throw UnimplementedError(
        'authorizedPost was not configured for this test.',
      );
    }
    return handler(path, body);
  }

  @override
  Future<void> clearSession() async => throw UnimplementedError();

  @override
  Future<AuthUserProfile> fetchCurrentUser({
    bool retryOnUnauthorized = true,
  }) async => throw UnimplementedError();

  @override
  Future<AuthSession> refreshSession() async => throw UnimplementedError();

  @override
  Future<AuthSession?> restoreSession() async => throw UnimplementedError();

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> signOut() async => throw UnimplementedError();
}

JsonApiResponse _jsonResponse(int statusCode, Map<String, Object?> body) {
  return JsonApiResponse(
    statusCode: statusCode,
    body: body,
    rawBody: jsonEncode(body),
  );
}
