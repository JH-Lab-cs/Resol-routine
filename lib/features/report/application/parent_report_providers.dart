import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_provider.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_repository.dart';
import '../../parent/application/parent_ui_providers.dart';
import '../data/parent_report_models.dart';
import '../data/parent_report_repository.dart';

final parentReportRepositoryProvider = Provider<ParentReportRepository>((
  Ref ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  return ParentReportRepository(authRepository: authRepository);
});

final selectedParentLinkedChildProvider = Provider<ParentLinkedChild?>((
  Ref ref,
) {
  final children = ref.watch(parentLinkedChildrenProvider);
  if (children.isEmpty) {
    return null;
  }
  final selectedChildId = ref.watch(selectedParentChildIdProvider);
  for (final child in children) {
    if (child.id == selectedChildId) {
      return child;
    }
  }
  return children.first;
});

final parentReportSummaryProvider = FutureProvider<ParentReportSummaryState>((
  Ref ref,
) async {
  final snapshot = await ref.watch(familyLinksProvider.future);
  ParentLinkedChild? child;
  final selectedChildId = ref.watch(selectedParentChildIdProvider);
  for (final linkedChild in snapshot.linkedChildren) {
    if (linkedChild.id == selectedChildId) {
      child = _toParentReportLinkedChild(linkedChild);
      break;
    }
  }
  child ??= snapshot.linkedChildren.isEmpty
      ? null
      : _toParentReportLinkedChild(snapshot.linkedChildren.first);
  if (child == null) {
    return const ParentReportSummaryState.noLinkedChild();
  }

  try {
    final summary = await ref
        .read(parentReportRepositoryProvider)
        .fetchParentReportSummary(childId: child.id);
    if (!summary.hasAnyReportData) {
      return ParentReportSummaryState.noData(
        child: summary.child,
        summary: summary,
      );
    }
    return ParentReportSummaryState.success(
      child: summary.child,
      summary: summary,
    );
  } on ParentReportRepositoryException catch (error) {
    if (error.isUnauthorized) {
      await ref.read(authSessionProvider.notifier).clearSessionOnly();
    }
    rethrow;
  }
});

final parentReportDetailProvider =
    FutureProvider.family<ParentReportDetail, String>((
      Ref ref,
      String childId,
    ) async {
      try {
        return await ref
            .read(parentReportRepositoryProvider)
            .fetchParentReportDetail(childId: childId);
      } on ParentReportRepositoryException catch (error) {
        if (error.isUnauthorized) {
          await ref.read(authSessionProvider.notifier).clearSessionOnly();
        }
        rethrow;
      }
    });

ParentLinkedChild _toParentReportLinkedChild(FamilyLinkedUserSummary child) {
  final localPart = child.email.split('@').first.trim();
  final displayName = localPart.isEmpty ? child.email : localPart;
  return ParentLinkedChild(
    id: child.id,
    displayName: displayName,
    subtitle: child.email,
  );
}
