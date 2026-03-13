import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resol_routine/core/database/app_database.dart';
import 'package:resol_routine/core/database/database_providers.dart';
import 'package:resol_routine/features/auth/application/auth_session_provider.dart';
import 'package:resol_routine/features/auth/data/auth_models.dart';
import 'package:resol_routine/features/family/application/family_providers.dart';
import 'package:resol_routine/features/family/data/family_repository.dart';
import '../../../test_helpers/fake_auth_session.dart';
import '../../../test_helpers/fake_family_repository.dart';

void main() {
  group('family providers', () {
    test('consumeChildLinkCode refreshes linked child state', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(role: AuthUserRole.parent),
          familyRepositoryProvider.overrideWithValue(
            FakeFamilyRepository(
              snapshot: parentFamilySnapshot(
                linkedChildren: <FamilyLinkedUserSummary>[
                  fakeLinkedFamilyUser(
                    id: 'child-1',
                    email: 'chulsoo@example.com',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(familyLinksProvider.future);
      expect(initial.linkedChildren, hasLength(1));

      await container
          .read(familyLinksProvider.notifier)
          .consumeChildLinkCode('654321');

      final updated = container.read(familyLinksProvider).valueOrNull;
      expect(updated?.linkedChildren, hasLength(2));
      expect(updated?.linkedChildren.last.email, 'student654321@example.com');
    });

    test(
      'familyLinksProvider signs out on unauthorized load failure',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);

        final container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(database),
            signedInAuthOverride(role: AuthUserRole.parent),
            familyRepositoryProvider.overrideWithValue(
              FakeFamilyRepository(
                loadError: const FamilyRepositoryException(
                  code: 'invalid_access_token',
                  message: 'expired',
                  statusCode: 401,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        unawaited(
          container.read(familyLinksProvider.future).then<void>(
            (_) {},
            onError: (_, _) {},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final authState = container.read(authSessionProvider);
        expect(authState.status, AuthSessionStatus.signedOut);
      },
    );

    test('studentLinkCodeProvider regenerate updates issued code', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final repository = _RotatingStudentCodeRepository();
      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(role: AuthUserRole.student),
          familyRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final firstCode = await container.read(studentLinkCodeProvider.future);
      expect(firstCode?.code, '654321');

      await container.read(studentLinkCodeProvider.notifier).regenerate();

      final secondCode = container.read(studentLinkCodeProvider).valueOrNull;
      expect(secondCode?.code, '654322');
    });
  });
}

class _RotatingStudentCodeRepository implements FamilyRepository {
  int _sequence = 654321;

  @override
  Future<FamilyLinkCode> createChildLinkCode() async {
    final code = _sequence.toString();
    _sequence += 1;
    return FamilyLinkCode(
      code: code,
      expiresAt: DateTime.utc(2026, 3, 13, 12, 10),
      activeParentCount: 0,
      maxParentsPerChild: 2,
    );
  }

  @override
  Future<FamilyLinkConsumeResult> consumeChildLinkCode(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<FamilyLinksSnapshot> loadFamilyLinks() async {
    return studentFamilySnapshot();
  }
}
