import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/label_maps.dart';
import '../../settings/application/user_settings_providers.dart';

enum _OnboardingStep { role, profile }

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final TextEditingController _nameController = TextEditingController();
  _OnboardingStep _step = _OnboardingStep.role;
  String? _selectedRole;
  String _selectedTrack = 'M3';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: _step == _OnboardingStep.role
              ? _buildRoleStep()
              : _buildProfileStep(),
        ),
      ),
    );
  }

  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('반가워요!', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '학습자 유형을 선택해 주세요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RoleCard(
          title: '학생',
          subtitle: '오늘 루틴과 단어 학습을 직접 진행해요.',
          icon: Icons.school_rounded,
          selected: _selectedRole == 'STUDENT',
          onTap: () {
            setState(() {
              _selectedRole = 'STUDENT';
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _RoleCard(
          title: '학부모',
          subtitle: '학습 진행 상황을 함께 확인해요.',
          icon: Icons.family_restroom_rounded,
          selected: _selectedRole == 'PARENT',
          onTap: () {
            setState(() {
              _selectedRole = 'PARENT';
            });
          },
        ),
        const Spacer(),
        PrimaryPillButton(
          label: '다음',
          onPressed: _selectedRole == null
              ? null
              : () {
                  setState(() {
                    _step = _OnboardingStep.profile;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    final name = _nameController.text.trim();
    final canSubmit =
        !_saving &&
        _selectedRole != null &&
        name.isNotEmpty &&
        name.length <= DbTextLimits.displayNameMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이름과 트랙을 설정해 주세요', style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '설정은 마이 페이지에서 언제든 변경할 수 있어요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          maxLength: DbTextLimits.displayNameMax,
          decoration: const InputDecoration(
            labelText: '이름',
            hintText: '예: 지훈',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('트랙', style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _trackOptions
              .map((track) {
                final selected = track == _selectedTrack;
                return ChoiceChip(
                  label: Text(displayTrack(track)),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: AppTypography.label.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedTrack = track;
                    });
                  },
                );
              })
              .toList(growable: false),
        ),
        const Spacer(),
        if (name.isNotEmpty && name.length > DbTextLimits.displayNameMax)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '이름은 ${DbTextLimits.displayNameMax}자 이하로 입력해 주세요.',
              style: AppTypography.label.copyWith(color: AppColors.danger),
            ),
          ),
        PrimaryPillButton(
          label: '시작하기',
          onPressed: canSubmit ? _completeOnboarding : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  setState(() {
                    _step = _OnboardingStep.role;
                  });
                },
          child: const Text('이전'),
        ),
      ],
    );
  }

  Future<void> _completeOnboarding() async {
    final role = _selectedRole;
    if (role == null) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty ||
        trimmedName.length > DbTextLimits.displayNameMax) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final notifier = ref.read(userSettingsProvider.notifier);
      await notifier.updateRole(role);
      await notifier.updateName(trimmedName);
      await notifier.updateTrack(_selectedTrack);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('설정 저장에 실패했습니다.\n$error')));
      setState(() {
        _saving = false;
      });
    }
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primaryContainer,
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.section),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _trackOptions = <String>['M3', 'H1', 'H2', 'H3'];
