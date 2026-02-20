import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/ui/app_tokens.dart';
import '../application/profile_ui_prefs_provider.dart';
import '../../settings/application/user_settings_providers.dart';
import 'membership_plan_screen.dart';

final mySettingsVersionProvider = FutureProvider<String>((Ref ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});

class MySettingsScreen extends ConsumerWidget {
  const MySettingsScreen({super.key});

  static const String _supportEmail = 'support@resolroutine.app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(userSettingsProvider);
    final versionAsync = ref.watch(mySettingsVersionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('설정')),
      body: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('설정을 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
        ),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mdLg,
              AppSpacing.sm,
              AppSpacing.mdLg,
              AppSpacing.lg,
            ),
            children: [
              const _SectionHeader(title: '멤버십'),
              const SizedBox(height: AppSpacing.xs),
              _ActionCard(
                title: '구독권 선택',
                subtitle: '학습 플랜을 선택하고 혜택을 확인하세요.',
                icon: Icons.workspace_premium_rounded,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const MembershipPlanScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.mdLg),
              const _SectionHeader(title: '알림'),
              const SizedBox(height: AppSpacing.xs),
              Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      title: '앱 푸시 알림',
                      value: settings.notificationsEnabled,
                      onChanged: (value) {
                        ref
                            .read(userSettingsProvider.notifier)
                            .updateNotificationsEnabled(value);
                      },
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _SwitchTile(
                      title: '마케팅 정보 수신',
                      value: settings.studyReminderEnabled,
                      onChanged: (value) {
                        ref
                            .read(userSettingsProvider.notifier)
                            .updateStudyReminderEnabled(value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.mdLg),
              const _SectionHeader(title: '지원'),
              const SizedBox(height: AppSpacing.xs),
              Card(
                child: Column(
                  children: [
                    _ListTile(
                      title: 'FAQ',
                      onTap: () => _openStaticInfo(
                        context,
                        const _StaticInfoScreen(
                          title: 'FAQ',
                          sections: [
                            _InfoSection(
                              title: '루틴 문제는 어떻게 집계되나요?',
                              body:
                                  '오늘 루틴은 듣기 3문제와 독해 3문제로 구성되며, 정답/오답 집계는 기기에 저장된 시도 기록을 기준으로 계산됩니다.',
                            ),
                            _InfoSection(
                              title: '트랙을 바꾸면 기존 기록은 사라지나요?',
                              body:
                                  '기존 기록은 유지됩니다. 다만 오늘 루틴은 선택한 트랙 기준으로 생성되어 표시됩니다.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _ListTile(
                      title: '문의하기',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _ContactSupportScreen(email: _supportEmail),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _ListTile(
                      title: '개인정보처리방침',
                      onTap: () => _openStaticInfo(
                        context,
                        const _StaticInfoScreen(
                          title: '개인정보처리방침',
                          sections: [
                            _InfoSection(
                              title: '수집 항목',
                              body:
                                  '이 앱은 학습 진행을 위해 이름, 역할, 트랙, 학습 설정 및 문제 풀이 기록을 저장합니다.',
                            ),
                            _InfoSection(
                              title: '보관 및 삭제',
                              body:
                                  '학습 데이터는 기본적으로 기기 내 로컬 데이터베이스에 저장됩니다. 로그아웃/탈퇴 시 계정 설정은 초기화됩니다.',
                            ),
                            _InfoSection(
                              title: '문의',
                              body: '개인정보 관련 문의: support@resolroutine.app',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: const Text('앱 버전'),
                  trailing: versionAsync.when(
                    loading: () => const Text('불러오는 중...'),
                    error: (_, _) => const Text('확인 불가'),
                    data: (value) => Text(
                      value,
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: () => _logout(context, ref),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('로그아웃'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                child: TextButton(
                  onPressed: () => _withdraw(context, ref),
                  child: Text(
                    '탈퇴하기',
                    style: AppTypography.label.copyWith(
                      color: const Color(0xFF8E93A3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openStaticInfo(BuildContext context, _StaticInfoScreen screen) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(userSettingsProvider.notifier).logout();
    _resetProfileUiPrefs(ref);
    ref.invalidate(selectedTrackProvider);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('탈퇴 처리되었습니다.')));
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
}

class _ContactSupportScreen extends StatelessWidget {
  const _ContactSupportScreen({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문의하기')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('문의 채널', style: AppTypography.section),
                  const SizedBox(height: AppSpacing.xs),
                  Text('이메일: $email', style: AppTypography.body),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '운영시간: 평일 10:00 - 18:00 (KST)',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이메일 주소를 복사했습니다.')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('이메일 복사'),
                  ),
                ],
              ),
            ),
          ),
        ],
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.mdLg,
          vertical: AppSpacing.sm,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: AppTypography.section),
        subtitle: Text(
          subtitle,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFABAFBC),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mdLg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.section)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.mdLg,
        vertical: AppSpacing.xxs,
      ),
      title: Text(title, style: AppTypography.section),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFFABAFBC),
      ),
      onTap: onTap,
    );
  }
}

class _StaticInfoScreen extends StatelessWidget {
  const _StaticInfoScreen({required this.title, required this.sections});

  final String title;
  final List<_InfoSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.title, style: AppTypography.section),
                  const SizedBox(height: AppSpacing.xs),
                  Text(section.body, style: AppTypography.body),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoSection {
  const _InfoSection({required this.title, required this.body});

  final String title;
  final String body;
}
