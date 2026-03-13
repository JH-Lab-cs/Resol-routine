import 'package:resol_routine/features/family/data/family_repository.dart';

class FakeFamilyRepository implements FamilyRepository {
  FakeFamilyRepository({
    FamilyLinkCode? childLinkCode,
    FamilyLinksSnapshot? snapshot,
    this.createError,
    this.consumeError,
    this.loadError,
  }) : _childLinkCode =
           childLinkCode ??
           FamilyLinkCode(
             code: '654321',
             expiresAt: DateTime.utc(2026, 3, 13, 12, 10),
             activeParentCount: 0,
             maxParentsPerChild: 2,
           ),
       _snapshot =
           snapshot ??
           const FamilyLinksSnapshot(
             role: FamilyLinksRole.student,
             linkedChildren: <FamilyLinkedUserSummary>[],
             linkedParents: <FamilyLinkedUserSummary>[],
             activeChildCount: 0,
             activeParentCount: 0,
             maxChildrenPerParent: 5,
             maxParentsPerChild: 2,
           );

  final FamilyLinkCode _childLinkCode;
  FamilyLinksSnapshot _snapshot;
  final FamilyRepositoryException? createError;
  final FamilyRepositoryException? consumeError;
  final FamilyRepositoryException? loadError;

  @override
  Future<FamilyLinkCode> createChildLinkCode() async {
    if (createError case final error?) {
      throw error;
    }
    return _childLinkCode;
  }

  @override
  Future<FamilyLinkConsumeResult> consumeChildLinkCode(String code) async {
    if (consumeError case final error?) {
      throw error;
    }

    final normalizedCode = code.trim();
    final linkedChild = FamilyLinkedUserSummary(
      id: 'child-$normalizedCode',
      email: 'student$normalizedCode@example.com',
      linkedAt: DateTime.utc(2026, 3, 13, 12, 20),
    );

    _snapshot = FamilyLinksSnapshot(
      role: _snapshot.role,
      linkedChildren: <FamilyLinkedUserSummary>[
        ..._snapshot.linkedChildren,
        linkedChild,
      ],
      linkedParents: _snapshot.linkedParents,
      activeChildCount: _snapshot.activeChildCount + 1,
      activeParentCount: _snapshot.activeParentCount,
      maxChildrenPerParent: _snapshot.maxChildrenPerParent,
      maxParentsPerChild: _snapshot.maxParentsPerChild,
    );

    return FamilyLinkConsumeResult(
      parentId: 'parent-1',
      childId: linkedChild.id,
      linkedAt: linkedChild.linkedAt,
    );
  }

  @override
  Future<FamilyLinksSnapshot> loadFamilyLinks() async {
    if (loadError case final error?) {
      throw error;
    }
    return _snapshot;
  }
}

FamilyLinksSnapshot studentFamilySnapshot({
  List<FamilyLinkedUserSummary> linkedParents =
      const <FamilyLinkedUserSummary>[],
  int maxParentsPerChild = 2,
}) {
  return FamilyLinksSnapshot(
    role: FamilyLinksRole.student,
    linkedChildren: const <FamilyLinkedUserSummary>[],
    linkedParents: linkedParents,
    activeChildCount: 0,
    activeParentCount: linkedParents.length,
    maxChildrenPerParent: 5,
    maxParentsPerChild: maxParentsPerChild,
  );
}

FamilyLinksSnapshot parentFamilySnapshot({
  List<FamilyLinkedUserSummary> linkedChildren =
      const <FamilyLinkedUserSummary>[],
  int maxChildrenPerParent = 5,
}) {
  return FamilyLinksSnapshot(
    role: FamilyLinksRole.parent,
    linkedChildren: linkedChildren,
    linkedParents: const <FamilyLinkedUserSummary>[],
    activeChildCount: linkedChildren.length,
    activeParentCount: 0,
    maxChildrenPerParent: maxChildrenPerParent,
    maxParentsPerChild: 2,
  );
}

FamilyLinkedUserSummary fakeLinkedFamilyUser({
  required String id,
  required String email,
  DateTime? linkedAt,
}) {
  return FamilyLinkedUserSummary(
    id: id,
    email: email,
    linkedAt: linkedAt ?? DateTime.utc(2026, 3, 13, 12, 20),
  );
}
