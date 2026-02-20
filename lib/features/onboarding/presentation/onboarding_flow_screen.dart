import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/input_formatters/birth_date_input_formatter.dart';
import '../../my/application/profile_ui_prefs_provider.dart';
import '../../settings/application/user_settings_providers.dart';

enum _OnboardingStep { login, profile }

const List<String> _studentGradeOptions = <String>['중3', '고1', '고2', '고3'];

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  _OnboardingStep _step = _OnboardingStep.login;
  String? _selectedRole;
  String _selectedGrade = '고1';
  bool _roleLocked = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _step == _OnboardingStep.login
                    ? _buildLoginStep()
                    : _buildProfileStep(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginStep() {
    return ListView(
      key: const ValueKey<String>('login_step'),
      children: [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Resol',
          textAlign: TextAlign.center,
          style: AppTypography.display.copyWith(
            fontSize: 54,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AI 영어 튜터와 함께하는\n스마트한 학습 루틴',
          textAlign: TextAlign.center,
          style: AppTypography.section.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 72),
        _SocialLoginButton(
          label: '카카오톡으로 계속하기',
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF1D1D1F),
          icon: const Icon(Icons.chat_bubble_rounded, size: 22),
          onTap: _openRoleSelector,
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialLoginButton(
          label: '네이버로 시작하기',
          backgroundColor: const Color(0xFF03C75A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.public_rounded, size: 22),
          onTap: _openRoleSelector,
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialLoginButton(
          label: 'Google로 계속하기',
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          borderColor: const Color(0xFFD9DCE7),
          icon: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            child: Text(
              'G',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          onTap: _openRoleSelector,
        ),
        const SizedBox(height: AppSpacing.md),
        _SocialLoginButton(
          label: 'Apple로 계속하기',
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.apple_rounded, size: 24),
          onTap: _openRoleSelector,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '로그인 시 이용약관 및 개인정보처리방침에 동의하게 됩니다.',
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.62),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildProfileStep() {
    final name = _nameController.text.trim();
    final role = _selectedRole;
    final isStudent = role != 'PARENT';
    final birthDate = _birthDateController.text.trim();
    final birthDateValid = birthDate.isEmpty || isValidBirthDateText(birthDate);
    final canSubmit =
        !_saving &&
        role != null &&
        name.isNotEmpty &&
        name.length <= DbTextLimits.displayNameMax &&
        birthDateValid;

    return ListView(
      key: const ValueKey<String>('profile_step'),
      children: [
        Text(
          '내 학습 정보 설정',
          style: AppTypography.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _roleLocked
              ? '선택한 유형은 계정 보호를 위해 고정되어 있어요.'
              : '선택한 유형에 맞는 정보를 입력해 주세요.',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role == 'PARENT' ? '학부모 계정 정보' : '학생 계정 정보',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: DbTextLimits.displayNameMax,
                decoration: const InputDecoration(
                  labelText: '이름',
                  hintText: '예: 지훈',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (isStudent) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('학습 학년 (추후 변경가능합니다)', style: AppTypography.label),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _studentGradeOptions
                      .map((grade) {
                        final selected = grade == _selectedGrade;
                        return ChoiceChip(
                          label: Text(grade),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: AppColors.primary,
                          labelStyle: AppTypography.label.copyWith(
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedGrade = grade;
                            });
                          },
                        );
                      })
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _birthDateController,
                keyboardType: TextInputType.number,
                inputFormatters: const [BirthDateTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: '생년월일(선택사항)',
                  hintText: 'YYYY-MM-DD',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (birthDate.isNotEmpty && !birthDateValid) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '생년월일 형식은 YYYY-MM-DD로 입력해 주세요.',
                  style: AppTypography.label.copyWith(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
      ],
    );
  }

  Future<void> _openRoleSelector() async {
    final settings = ref.read(userSettingsProvider).valueOrNull;
    final roleLocked =
        settings != null &&
        settings.displayName.trim().isEmpty &&
        settings.updatedAt.isAfter(settings.createdAt);
    if (roleLocked) {
      final prefs = ref.read(profileUiPrefsProvider);
      setState(() {
        _selectedRole = settings.role;
        _selectedGrade = _gradeFromTrack(settings.track);
        _birthDateController.text = settings.birthDate.isEmpty
            ? prefs.birthDate
            : settings.birthDate;
        _roleLocked = true;
        _step = _OnboardingStep.profile;
      });
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('누가 사용하나요?', style: AppTypography.title),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '맞춤형 학습 분석을 위해 선택해 주세요.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.mdLg),
                Row(
                  children: [
                    Expanded(
                      child: _RoleSelectTile(
                        title: '학생',
                        subtitle: '직접 학습을 진행해요',
                        icon: Icons.school_rounded,
                        tint: AppColors.primary,
                        onTap: () => Navigator.of(context).pop('STUDENT'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _RoleSelectTile(
                        title: '학부모',
                        subtitle: '학습 진행을 확인해요',
                        icon: Icons.family_restroom_rounded,
                        tint: const Color(0xFFF07A53),
                        onTap: () => Navigator.of(context).pop('PARENT'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedRole = selected;
      _birthDateController.clear();
      _roleLocked = false;
      _step = _OnboardingStep.profile;
    });
  }

  Future<void> _completeOnboarding() async {
    final role = _selectedRole;
    if (role == null) {
      return;
    }

    final trimmedName = _nameController.text.trim();
    final trimmedBirthDate = _birthDateController.text.trim();
    final isStudent = role == 'STUDENT';
    if (trimmedName.isEmpty ||
        trimmedName.length > DbTextLimits.displayNameMax) {
      return;
    }
    if (trimmedBirthDate.isNotEmpty &&
        !isValidBirthDateText(trimmedBirthDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 YYYY-MM-DD 형식으로 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final notifier = ref.read(userSettingsProvider.notifier);
      final track = isStudent ? _mapGradeToTrack(_selectedGrade) : 'M3';
      await notifier.updateRole(role);
      await notifier.updateName(trimmedName);
      await notifier.updateTrack(track);
      await notifier.updateBirthDate(trimmedBirthDate);
      final prefs = ref.read(profileUiPrefsProvider);
      if (isStudent) {
        ref.read(profileUiPrefsProvider.notifier).state = prefs.copyWith(
          schoolName: '학교 미설정',
          listeningGradeLabel: _selectedGrade,
          readingGradeLabel: _selectedGrade,
          ageLabel: _selectedGrade,
          birthDate: trimmedBirthDate,
        );
      } else {
        ref.read(profileUiPrefsProvider.notifier).state = prefs.copyWith(
          schoolName: '학부모 계정',
          listeningGradeLabel: '고1',
          readingGradeLabel: '고1',
          ageLabel: '성인',
          birthDate: trimmedBirthDate,
        );
      }
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

  String _mapGradeToTrack(String grade) {
    switch (grade) {
      case '중3':
        return 'M3';
      case '고1':
        return 'H1';
      case '고2':
        return 'H2';
      case '고3':
        return 'H3';
      default:
        return 'H1';
    }
  }

  String _gradeFromTrack(String track) {
    switch (track) {
      case 'M3':
        return '중3';
      case 'H1':
        return '고1';
      case 'H2':
        return '고2';
      case 'H3':
        return '고3';
      default:
        return '고1';
    }
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.buttonPill),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1.2),
          ),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: icon,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.section.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                  ),
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSelectTile extends StatelessWidget {
  const _RoleSelectTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: tint.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.16),
                      blurRadius: 20,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, color: tint, size: 34),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTypography.section),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
