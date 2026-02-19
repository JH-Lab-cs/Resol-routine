import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_scaffold.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/components/track_picker.dart';
import '../../../core/ui/label_maps.dart';
import '../../home/application/home_providers.dart';
import '../../settings/application/user_settings_providers.dart';
import '../../settings/data/user_settings_repository.dart';
import '../../today/application/today_quiz_providers.dart';
import '../../today/application/today_session_providers.dart'
    hide selectedTrackProvider;
import '../../wrong_notes/application/wrong_note_providers.dart';

final appVersionBuildProvider = FutureProvider<String>((Ref ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
});

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(userSettingsProvider);
    final versionAsync = ref.watch(appVersionBuildProvider);

    return AppPageBody(
      child: settingsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('내 정보를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
        ),
        data: (settings) {
          final track = settings.track;
          return ListView(
            children: [
              _ProfileCard(
                displayName: settings.displayName.trim().isEmpty
                    ? '지훈'
                    : settings.displayName.trim(),
                role: settings.role,
                track: track,
                onEditProfile: () =>
                    _showEditProfileSheet(context, ref, settings),
                onChangeTrack: () async {
                  final selected = await showTrackPickerBottomSheet(
                    context,
                    selectedTrack: track,
                  );
                  if (selected == null || selected == track) {
                    return;
                  }
                  await ref
                      .read(selectedTrackProvider.notifier)
                      .setTrack(selected);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsSectionCard(
                title: '알림',
                children: [
                  SwitchListTile(
                    value: settings.notificationsEnabled,
                    onChanged: (value) {
                      ref
                          .read(userSettingsProvider.notifier)
                          .updateNotificationsEnabled(value);
                    },
                    title: const Text('학습 알림 받기'),
                    subtitle: const Text('오늘 루틴 시작을 알려드려요.'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  SwitchListTile(
                    value: settings.studyReminderEnabled,
                    onChanged: (value) {
                      ref
                          .read(userSettingsProvider.notifier)
                          .updateStudyReminderEnabled(value);
                    },
                    title: const Text('복습 리마인더'),
                    subtitle: const Text('오답/단어 복습 시점을 알려드려요.'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsSectionCard(
                title: '지원',
                children: [
                  _SupportTile(
                    title: '공지사항',
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const _StaticInfoScreen(
                            title: '공지사항',
                            sections: [
                              _InfoSection(
                                title: '서비스 운영 안내',
                                body:
                                    '매일 루틴은 로컬 기기 기준 날짜로 생성됩니다. 앱 업데이트 후에는 최신 기능과 안정성 개선 사항이 자동으로 적용됩니다.',
                              ),
                              _InfoSection(
                                title: '데이터 저장',
                                body:
                                    '학습 기록은 기기 내부 데이터베이스에 저장되며, 앱 삭제 시 함께 제거될 수 있습니다.',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SupportTile(
                    title: 'FAQ',
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const _StaticInfoScreen(
                            title: 'FAQ',
                            sections: [
                              _InfoSection(
                                title: 'Q. 하루 루틴은 몇 문제인가요?',
                                body: 'A. 듣기 3문제와 독해 3문제, 총 6문제로 고정됩니다.',
                              ),
                              _InfoSection(
                                title: 'Q. 트랙은 어디서 변경하나요?',
                                body:
                                    'A. 마이 페이지의 내 정보 카드에서 트랙 변경 버튼으로 수정할 수 있습니다.',
                              ),
                              _InfoSection(
                                title: 'Q. 오답 이유 태그는 왜 선택하나요?',
                                body:
                                    'A. 자주 틀리는 원인을 파악해 다음 학습에서 약점을 우선 보완하기 위해 사용합니다.',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SupportTile(
                    title: '문의하기',
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const _StaticInfoScreen(
                            title: '문의하기',
                            sections: [
                              _InfoSection(
                                title: '문의 채널',
                                body:
                                    '이메일: support@resolroutine.app\n운영시간: 평일 10:00 - 18:00 (KST)',
                              ),
                              _InfoSection(
                                title: '빠른 답변을 위한 안내',
                                body:
                                    '문의 시 사용 기기(OS), 앱 버전, 재현 절차를 함께 보내주시면 더 정확하게 도와드릴 수 있습니다.',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(child: Text('앱 버전')),
                      versionAsync.when(
                        loading: () => const Text('불러오는 중...'),
                        error: (_, _) => const Text('확인 불가'),
                        data: (value) => Text(
                          value,
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!kReleaseMode) ...[
                const SizedBox(height: AppSpacing.lg),
                PrimaryPillButton(
                  label: '오늘 세션만 삭제 (개발용)',
                  onPressed: () => _deleteTodaySession(context, ref, track),
                ),
              ],
            ],
          );
        },
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
    ref.invalidate(wrongNoteListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 세션을 삭제했습니다.')));
    }
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    UserSettingsModel settings,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: settings.displayName);
    var selectedRole = settings.role;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('내 정보 수정', style: AppTypography.section),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: nameController,
                        maxLength: DbTextLimits.displayNameMax,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          counterText: '',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return '이름을 입력해 주세요.';
                          }
                          if (text.length > DbTextLimits.displayNameMax) {
                            return '이름은 ${DbTextLimits.displayNameMax}자 이하로 입력해 주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('역할', style: AppTypography.label),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          ChoiceChip(
                            label: const Text('학생'),
                            selected: selectedRole == 'STUDENT',
                            showCheckmark: false,
                            onSelected: (_) {
                              setModalState(() {
                                selectedRole = 'STUDENT';
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('학부모'),
                            selected: selectedRole == 'PARENT',
                            showCheckmark: false,
                            onSelected: (_) {
                              setModalState(() {
                                selectedRole = 'PARENT';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }
                                      setModalState(() {
                                        isSaving = true;
                                      });

                                      try {
                                        final notifier = ref.read(
                                          userSettingsProvider.notifier,
                                        );
                                        await notifier.updateRole(selectedRole);
                                        await notifier.updateName(
                                          nameController.text.trim(),
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                      } catch (error) {
                                        if (!sheetContext.mounted) {
                                          return;
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '저장에 실패했습니다.\n$error',
                                            ),
                                          ),
                                        );
                                        setModalState(() {
                                          isSaving = false;
                                        });
                                      }
                                    },
                              child: const Text('저장'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.displayName,
    required this.role,
    required this.track,
    required this.onEditProfile,
    required this.onChangeTrack,
  });

  final String displayName;
  final String role;
  final String track;
  final VoidCallback onEditProfile;
  final VoidCallback onChangeTrack;

  @override
  Widget build(BuildContext context) {
    final trimmedName = displayName.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName.substring(0, 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mdLg),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    initial,
                    style: AppTypography.section.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: AppTypography.section),
                      const SizedBox(height: AppSpacing.xxs),
                      _RoleBadge(role: role),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  '현재 트랙: ${displayTrack(track)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: onChangeTrack, child: const Text('변경')),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: onEditProfile,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '내 정보 수정',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isParent = role == 'PARENT';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isParent
            ? AppColors.warning.withValues(alpha: 0.16)
            : AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isParent ? '학부모' : '학생',
        style: AppTypography.label.copyWith(
          color: isParent ? const Color(0xFF8A5400) : AppColors.primary,
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(title, style: AppTypography.section),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
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
