import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_providers.dart';
import '../../family/data/family_repository.dart';

class ParentLinkedChild {
  const ParentLinkedChild({
    required this.id,
    required this.displayName,
    required this.subtitle,
  });

  final String id;
  final String displayName;
  final String subtitle;
}

class ParentNotificationItem {
  const ParentNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.relativeTime,
    required this.emoji,
  });

  final String id;
  final String title;
  final String message;
  final String relativeTime;
  final String emoji;
}

final parentLinkedChildrenProvider = Provider<List<ParentLinkedChild>>((
  Ref ref,
) {
  final snapshot = ref.watch(familyLinksProvider).valueOrNull;
  if (snapshot == null) {
    return const <ParentLinkedChild>[];
  }
  return snapshot.linkedChildren
      .map(_toParentLinkedChild)
      .toList(growable: false);
});

final selectedParentChildIdProvider = StateProvider<String?>((Ref ref) => null);

final parentNotificationItemsProvider = Provider<List<ParentNotificationItem>>((
  Ref ref,
) {
  return const <ParentNotificationItem>[
    ParentNotificationItem(
      id: 'notif-deadline',
      title: '숙제 마감 알림',
      message: '수학 숙제가 오늘 마감이에요!',
      relativeTime: '방금 전',
      emoji: '📣',
    ),
    ParentNotificationItem(
      id: 'notif-cheer',
      title: '오늘의 응원',
      message: '오늘도 힘차게 시작해봐요!',
      relativeTime: '1시간 전',
      emoji: '🍀',
    ),
    ParentNotificationItem(
      id: 'notif-update',
      title: '업데이트 공지',
      message: '학부모 홈 화면이 개선되었습니다.',
      relativeTime: '어제',
      emoji: '🛠️',
    ),
  ];
});

final studentNotificationItemsProvider = Provider<List<ParentNotificationItem>>(
  (Ref ref) {
    return const <ParentNotificationItem>[
      ParentNotificationItem(
        id: 'student-notif-routine',
        title: '오늘 루틴 알림',
        message: '오늘의 6문제 루틴을 시작해 보세요!',
        relativeTime: '방금 전',
        emoji: '🔥',
      ),
      ParentNotificationItem(
        id: 'student-notif-vocab',
        title: '단어 시험 리마인더',
        message: '오늘의 단어 시험 20문제를 아직 풀지 않았어요.',
        relativeTime: '45분 전',
        emoji: '📘',
      ),
      ParentNotificationItem(
        id: 'student-notif-cheer',
        title: '오늘의 응원',
        message: '작은 진전이 쌓이면 큰 실력이 됩니다.',
        relativeTime: '어제',
        emoji: '🍀',
      ),
    ];
  },
);

ParentLinkedChild _toParentLinkedChild(FamilyLinkedUserSummary child) {
  final localPart = child.email.split('@').first.trim();
  final displayName = localPart.isEmpty ? child.email : localPart;
  return ParentLinkedChild(
    id: child.id,
    displayName: displayName,
    subtitle: child.email,
  );
}
