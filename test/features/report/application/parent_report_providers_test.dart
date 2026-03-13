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
import 'package:resol_routine/features/report/application/parent_report_providers.dart';
import 'package:resol_routine/features/report/data/parent_report_models.dart';
import '../../../test_helpers/fake_auth_session.dart';
import '../../../test_helpers/fake_family_repository.dart';
import '../../../test_helpers/fake_parent_report_repository.dart';

void main() {
  group('parent report providers', () {
    test('summary provider returns no-linked-child empty state', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          signedInAuthOverride(role: AuthUserRole.parent),
          familyRepositoryProvider.overrideWithValue(
            FakeFamilyRepository(snapshot: parentFamilySnapshot()),
          ),
          parentReportRepositoryProvider.overrideWithValue(
            FakeParentReportRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(parentReportSummaryProvider.future);
      expect(result.emptyReason, ParentReportEmptyReason.noLinkedChild);
    });

    test('summary provider signs out on unauthorized backend error', () async {
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
          parentReportRepositoryProvider.overrideWithValue(
            FakeParentReportRepository(
              summaryError: const ParentReportRepositoryException(
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
        container
            .read(parentReportSummaryProvider.future)
            .then<void>((_) {}, onError: (_, _) {}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final authState = container.read(authSessionProvider);
      expect(authState.status, AuthSessionStatus.signedOut);
    });
  });
}
