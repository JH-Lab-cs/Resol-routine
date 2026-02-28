import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ParentChildLearningState { active, resting }

class ParentLinkedChild {
  const ParentLinkedChild({
    required this.id,
    required this.displayName,
    required this.inviteCode,
    required this.state,
    required this.streakDays,
  });

  final String id;
  final String displayName;
  final String inviteCode;
  final ParentChildLearningState state;
  final int streakDays;

  ParentLinkedChild copyWith({
    String? id,
    String? displayName,
    String? inviteCode,
    ParentChildLearningState? state,
    int? streakDays,
  }) {
    return ParentLinkedChild(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      inviteCode: inviteCode ?? this.inviteCode,
      state: state ?? this.state,
      streakDays: streakDays ?? this.streakDays,
    );
  }
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

class ParentLinkedChildrenNotifier extends Notifier<List<ParentLinkedChild>> {
  static final RegExp _inviteCodePattern = RegExp(r'^\d{6}$');

  @override
  List<ParentLinkedChild> build() {
    return const <ParentLinkedChild>[
      ParentLinkedChild(
        id: 'child-1',
        displayName: '김철수',
        inviteCode: '123456',
        state: ParentChildLearningState.active,
        streakDays: 3,
      ),
      ParentLinkedChild(
        id: 'child-2',
        displayName: '김영희',
        inviteCode: '222222',
        state: ParentChildLearningState.resting,
        streakDays: 0,
      ),
    ];
  }

  ParentLinkedChild addChildFromInviteCode(String rawInviteCode) {
    final inviteCode = rawInviteCode.trim();
    if (!_inviteCodePattern.hasMatch(inviteCode)) {
      throw const FormatException('inviteCode must be exactly 6 digits.');
    }

    final duplicate = state.any((child) => child.inviteCode == inviteCode);
    if (duplicate) {
      throw const FormatException('inviteCode is already linked.');
    }

    final child = ParentLinkedChild(
      id: 'child-${DateTime.now().microsecondsSinceEpoch}',
      displayName: '자녀 ${state.length + 1}',
      inviteCode: inviteCode,
      state: ParentChildLearningState.resting,
      streakDays: 0,
    );
    state = <ParentLinkedChild>[...state, child];
    return child;
  }
}

final parentLinkedChildrenProvider =
    NotifierProvider<ParentLinkedChildrenNotifier, List<ParentLinkedChild>>(
      ParentLinkedChildrenNotifier.new,
    );

final selectedParentChildIdProvider = StateProvider<String?>((Ref ref) {
  final children = ref.watch(parentLinkedChildrenProvider);
  if (children.isEmpty) {
    return null;
  }
  return children.first.id;
});

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
