import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/label_maps.dart';
import '../../home/application/home_providers.dart';
import '../application/my_stats_providers.dart';
import '../../settings/application/user_settings_providers.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../today/application/today_quiz_providers.dart';
import '../../today/application/today_session_providers.dart'
    hide selectedTrackProvider;
import '../../wrong_notes/application/wrong_note_providers.dart';
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
          child: Text('내 정보를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
        ),
        data: (settings) {
          final profilePrefs = ref.watch(profileUiPrefsProvider);
          final statsAsync = ref.watch(myStatsProvider(settings.track));
          final stats = statsAsync.valueOrNull;
          final todayCompletedItems = stats?.todayCompletedItems ?? 0;
          final weeklyCompletedDays = stats?.weeklyCompletedDays ?? 0;
          final totalAttempts = stats?.totalAttempts ?? 0;
          final totalWrongAttempts = stats?.totalWrongAttempts ?? 0;

          return ListView(
            children: [
              Row(
                children: [
                  Text('내 정보', style: AppTypography.title),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const MySettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE9EBF3),
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(48, 48),
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
                childAspectRatio: 1.16,
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
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFF3EA65A),
                    iconBackground: const Color(0xFFDDF3E3),
                    value: '$weeklyCompletedDays일',
                    label: '최근 7일 완료 일수',
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
              if (!kReleaseMode) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: () =>
                      _deleteTodaySession(context, ref, settings.track),
                  child: const Text('오늘 세션만 삭제 (개발용)'),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('오늘 세션을 삭제했습니다.')));
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
          color: const Color(0xFF787D8D),
          fontWeight: FontWeight.w700,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBackground,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const Spacer(),
            Text(
              value,
              style: AppTypography.display.copyWith(
                fontSize: 46 / 2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
