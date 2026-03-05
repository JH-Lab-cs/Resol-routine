import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../../core/ui/label_maps.dart';
import '../../dev/application/dev_tools_providers.dart';
import '../../dev/presentation/dev_reports_screen.dart';
import '../../home/application/home_providers.dart';
import '../../mock_exam/presentation/mock_exam_history_screen.dart';
import '../../parent/application/parent_ui_providers.dart';
import '../../parent/presentation/parent_ui_helpers.dart';
import '../application/my_stats_providers.dart';
import '../../settings/application/user_settings_providers.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../today/application/today_quiz_providers.dart';
import '../../today/application/today_session_providers.dart'
    hide selectedTrackProvider;
import '../../wrong_notes/application/wrong_note_providers.dart';
import '../../wrong_notes/presentation/wrong_notes_screen.dart';
import '../../report/presentation/student_report_screen.dart';
import '../../vocab/presentation/vocab_screen.dart';
import '../application/profile_ui_prefs_provider.dart';
import 'my_settings_screen.dart';
import 'profile_manage_screen.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(userSettingsProvider);

    return AppPageBody(
      child: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '${AppCopyKo.loadFailed('내 정보')}\n$error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (settings) {
          final devToolsVisible = ref.watch(devToolsVisibleProvider);
          final profilePrefs = ref.watch(profileUiPrefsProvider);
          final statsAsync = ref.watch(myStatsProvider(settings.track));
          final stats = statsAsync.valueOrNull;
          final todayCompletedItems = stats?.todayCompletedItems ?? 0;
          final attendanceStreakDays = stats?.attendanceStreakDays ?? 0;
          final totalAttempts = stats?.totalAttempts ?? 0;
          final totalWrongAttempts = stats?.totalWrongAttempts ?? 0;

          if (settings.role == 'PARENT') {
            return _ParentMySettingsContent(
              settings: settings,
              devToolsVisible: devToolsVisible,
              onLogout: () => _logout(context, ref),
              onWithdraw: () => _withdraw(context, ref),
            );
          }

          return ListView(
            children: [
              Row(
                children: [
                  Text('내 정보', style: AppTypography.title),
                  const Spacer(),
                  Semantics(
                    label: '설정',
                    button: true,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const MySettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: '설정',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE9EBF3),
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileHeadlineCard(
                settings: settings,
                profilePrefs: profilePrefs,
                onTap: () => _openProfileManage(context, settings),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionHeader(title: '이번 주 활동'),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                children: [
                  _ActivityCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF2D8BE7),
                    iconBackground: const Color(0xFFDCEBFB),
                    value: '$todayCompletedItems/6',
                    label: '오늘 루틴 완료',
                  ),
                  _ActivityCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFE9533E),
                    iconBackground: const Color(0xFFFFE7D6),
                    value: '$attendanceStreakDays일',
                    label: '연속 출석',
                  ),
                  _ActivityCard(
                    icon: Icons.assignment_turned_in_rounded,
                    iconColor: const Color(0xFFF09B2D),
                    iconBackground: const Color(0xFFFFEED8),
                    value: '$totalAttempts회',
                    label: '총 시도',
                  ),
                  _ActivityCard(
                    icon: Icons.error_outline_rounded,
                    iconColor: const Color(0xFFE9533E),
                    iconBackground: const Color(0xFFFCE2DF),
                    value: '$totalWrongAttempts회',
                    label: '총 오답',
                  ),
                ],
              ),
              if (settings.role == 'STUDENT') ...[
                const SizedBox(height: AppSpacing.mdLg),
                const _SectionHeader(title: '나의 보관함'),
                const SizedBox(height: AppSpacing.sm),
                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  children: [
                    _StorageActionCard(
                      key: const ValueKey<String>('my-storage-wrong-notes'),
                      title: '오답 노트',
                      subtitle: '틀린 문제 다시보기',
                      icon: Icons.sell_outlined,
                      iconColor: const Color(0xFFE85757),
                      iconBackground: const Color(0xFFFFE4E4),
                      backgroundColor: const Color(0xFFFFF0F0),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                              appBar: _MyStorageAppBar(title: '오답 노트'),
                              body: WrongNotesScreen(showSectionHeader: false),
                            ),
                          ),
                        );
                      },
                    ),
                    _StorageActionCard(
                      key: const ValueKey<String>('my-storage-vocab'),
                      title: '단어장',
                      subtitle: '저장한 단어 복습',
                      icon: Icons.bookmark_outline_rounded,
                      iconColor: const Color(0xFF2993E7),
                      iconBackground: const Color(0xFFD9EEFF),
                      backgroundColor: const Color(0xFFEEF7FF),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                              appBar: _MyStorageAppBar(title: '단어장'),
                              body: VocabScreen(showSectionHeader: false),
                            ),
                          ),
                        );
                      },
                    ),
                    _StorageActionCard(
                      key: const ValueKey<String>('my-storage-report'),
                      title: '학습 리포트',
                      subtitle: '오늘 학습 결과 확인',
                      icon: Icons.insert_chart_outlined_rounded,
                      iconColor: const Color(0xFF6B58E5),
                      iconBackground: const Color(0xFFE7DFFF),
                      backgroundColor: const Color(0xFFF4F0FF),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                StudentReportScreen(track: settings.track),
                          ),
                        );
                      },
                    ),
                    _StorageActionCard(
                      key: const ValueKey<String>('my-storage-mock-history'),
                      title: '모의고사 기록',
                      subtitle: '주간/월간 결과 확인',
                      icon: Icons.folder_open_rounded,
                      iconColor: const Color(0xFF7D879A),
                      iconBackground: const Color(0xFFE8ECF3),
                      backgroundColor: const Color(0xFFF3F5F9),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MockExamHistoryScreen(track: settings.track),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
              if (!kReleaseMode) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: () =>
                      _deleteTodaySession(context, ref, settings.track),
                  child: const Text('오늘 세션만 삭제 (개발용)'),
                ),
              ],
              if (devToolsVisible) ...[
                const SizedBox(height: AppSpacing.lg),
                const _SectionHeader(title: '개발자'),
                const SizedBox(height: AppSpacing.sm),
                Card(
                  child: ListTile(
                    key: const ValueKey<String>('my-dev-reports-entry'),
                    leading: const Icon(Icons.developer_mode_rounded),
                    title: const Text('리포트(파일 기반)'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const DevReportsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }

  void _openProfileManage(BuildContext context, UserSettingsModel settings) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileManageScreen(initialSettings: settings),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(userSettingsProvider.notifier).logout();
    _resetProfileUiPrefs(ref);
    ref.invalidate(selectedTrackProvider);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    AppSnackbars.showSuccess(context, AppCopyKo.logoutSuccess);
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('탈퇴하기'),
          content: const Text('계정 정보를 초기화하고 로그아웃합니다. 진행할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('탈퇴'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(userSettingsProvider.notifier).withdraw();
    _resetProfileUiPrefs(ref);
    ref.invalidate(selectedTrackProvider);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    AppSnackbars.showSuccess(context, AppCopyKo.withdrawSuccess);
  }

  void _resetProfileUiPrefs(WidgetRef ref) {
    ref.read(profileUiPrefsProvider.notifier).state = const ProfileUiPrefs(
      schoolName: '학교 미설정',
      listeningGradeLabel: '고1',
      readingGradeLabel: '고1',
      ageLabel: '고1',
      birthDate: '',
      avatarImagePath: null,
    );
  }

  Future<void> _deleteTodaySession(
    BuildContext context,
    WidgetRef ref,
    String track,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('오늘 세션 삭제'),
          content: const Text('오늘 선택한 트랙의 세션만 삭제합니다.\n계속할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(todayQuizRepositoryProvider)
        .deleteTodaySession(track: track);
    ref.invalidate(todaySessionProvider(track));
    ref.invalidate(homeRoutineSummaryProvider(track));
    ref.invalidate(myStatsProvider(track));
    ref.invalidate(wrongNoteListProvider);

    if (!context.mounted) {
      return;
    }
    AppSnackbars.showSuccess(context, AppCopyKo.todaySessionDeleteSuccess);
  }
}

class _MyStorageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MyStorageAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title));
  }
}

class _ProfileHeadlineCard extends StatelessWidget {
  const _ProfileHeadlineCard({
    required this.settings,
    required this.profilePrefs,
    required this.onTap,
  });

  final UserSettingsModel settings;
  final ProfileUiPrefs profilePrefs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = settings.displayName.trim().isEmpty
        ? '이름 미설정'
        : settings.displayName.trim();
    final schoolName = profilePrefs.schoolName.trim().isEmpty
        ? '학교 미설정'
        : profilePrefs.schoolName.trim();
    final currentGradeLabel = profilePrefs.ageLabel.trim().isEmpty
        ? displayTrack(settings.track)
        : profilePrefs.ageLabel.trim();
    final profileLine = settings.role == 'PARENT'
        ? '학부모 계정'
        : '$schoolName | $currentGradeLabel';
    final accountLine = settings.role == 'PARENT' ? '학부모 계정' : '학생 계정';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card + 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF4F5FB),
                  border: Border.all(
                    color: const Color(0xFFD8DCF2),
                    width: 1.6,
                  ),
                ),
                child: _ProfileAvatar(
                  avatarImagePath: profilePrefs.avatarImagePath,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$displayName 님',
                      style: AppTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      profileLine,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      accountLine,
                      style: AppTypography.section.copyWith(
                        color: AppColors.primary,
                        fontSize: 33 / 1.6,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 32,
                color: Color(0xFFC8CAD4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatarImagePath});

  final String? avatarImagePath;

  @override
  Widget build(BuildContext context) {
    final path = avatarImagePath;
    if (path == null || path.isEmpty) {
      return const Icon(
        Icons.person_rounded,
        size: 44,
        color: Color(0xFF9EA2AD),
      );
    }

    final avatarFile = File(path);
    if (!avatarFile.existsSync()) {
      return const Icon(
        Icons.person_rounded,
        size: 44,
        color: Color(0xFF9EA2AD),
      );
    }

    return ClipOval(
      child: Image.file(
        avatarFile,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.person_rounded,
            size: 44,
            color: Color(0xFF9EA2AD),
          );
        },
      ),
    );
  }
}

class _ParentMySettingsContent extends ConsumerWidget {
  const _ParentMySettingsContent({
    required this.settings,
    required this.devToolsVisible,
    required this.onLogout,
    required this.onWithdraw,
  });

  final UserSettingsModel settings;
  final bool devToolsVisible;
  final Future<void> Function() onLogout;
  final Future<void> Function() onWithdraw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentLinkedChildrenProvider);

    return ListView(
      children: [
        Text('학부모 설정', style: AppTypography.title),
        const SizedBox(height: AppSpacing.mdLg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF1F2F6),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 42,
                  color: Color(0xFFA4A7AF),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settings.displayName.trim().isEmpty ? '이름 미설정' : settings.displayName.trim()} 님',
                      style: AppTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '학부모 회원',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text('연결된 자녀', style: AppTypography.section),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showAddChildDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (children.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('연결된 자녀가 없습니다.'),
            ),
          )
        else
          Column(
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ParentLinkedChildCard(
                    child: child,
                    onManage: () =>
                        showParentChildManageSheet(context, ref, child: child),
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeader(title: '설정'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('학습 알림 설정'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openAlertSettingSheet(context, ref),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeader(title: '지원'),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('공지사항'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSimpleInfoDialog(
                  context,
                  title: '공지사항',
                  message: '최근 공지사항이 없습니다.',
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(Icons.headset_mic_outlined),
                title: const Text('1:1 문의하기'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSimpleInfoDialog(
                  context,
                  title: '1:1 문의하기',
                  message: 'support@resolroutine.app 으로 문의해 주세요.',
                ),
              ),
            ],
          ),
        ),
        if (devToolsVisible) ...[
          const SizedBox(height: AppSpacing.xl),
          const _SectionHeader(title: '개발자'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              key: const ValueKey<String>('parent-my-dev-reports-entry'),
              leading: const Icon(Icons.developer_mode_rounded),
              title: const Text('리포트(파일 기반)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const DevReportsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFE9493D),
            minimumSize: const Size(double.infinity, 56),
          ),
          onPressed: onLogout,
          child: const Text('로그아웃'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          child: TextButton(
            onPressed: onWithdraw,
            child: Text(
              '회원 탈퇴',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAlertSettingSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(userSettingsProvider).valueOrNull;
    final notifications = settings?.notificationsEnabled ?? true;
    final reminders = settings?.studyReminderEnabled ?? true;
    var localNotifications = notifications;
    var localReminders = reminders;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.mdLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('학습 알림 설정', style: AppTypography.section),
                        const Spacer(),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      title: const Text('앱 푸시 알림'),
                      value: localNotifications,
                      onChanged: (value) {
                        setModalState(() {
                          localNotifications = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('학습 리마인더'),
                      value: localReminders,
                      onChanged: (value) {
                        setModalState(() {
                          localReminders = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: () async {
                        await ref
                            .read(userSettingsProvider.notifier)
                            .updateNotificationsEnabled(localNotifications);
                        await ref
                            .read(userSettingsProvider.notifier)
                            .updateStudyReminderEnabled(localReminders);
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSimpleInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

class _ParentLinkedChildCard extends StatelessWidget {
  const _ParentLinkedChildCard({required this.child, required this.onManage});

  final ParentLinkedChild child;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final (statusText, statusColor) = switch (child.state) {
      ParentChildLearningState.active => (
        '🔥 ${child.streakDays}일 연속 학습 중',
        const Color(0xFF44A84F),
      ),
      ParentChildLearningState.resting => (
        '💤 오늘은 쉬고 있어요',
        const Color(0xFF44A84F),
      ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onManage,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.mdLg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: const Color(0xFFBEC4FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEDEFFE),
              ),
              child: const Icon(
                Icons.face_2_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.displayName,
                    style: AppTypography.section.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    statusText,
                    style: AppTypography.section.copyWith(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 44),
                textStyle: AppTypography.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('관리'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.section.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StorageActionCard extends StatelessWidget {
  const _StorageActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.backgroundColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const Spacer(),
              Text(
                title,
                style: AppTypography.section,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 170;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isCompact ? 48 : 52,
                  height: isCompact ? 48 : 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBackground,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: isCompact ? 28 : 30,
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTypography.display.copyWith(
                      fontSize: isCompact ? 42 / 2 : 46 / 2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isCompact ? 15 : null,
                    height: 1.22,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
