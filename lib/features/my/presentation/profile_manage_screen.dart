import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/db_text_limits.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/primary_pill_button.dart';
import '../../../core/ui/input_formatters/birth_date_input_formatter.dart';
import '../../settings/application/user_settings_providers.dart';
import '../../settings/data/user_settings_repository.dart';
import '../application/profile_ui_prefs_provider.dart';

const List<String> _learningGradeOptions = <String>['중3', '고1', '고2', '고3'];

const List<String> _ageOptions = <String>[
  '중1',
  '중2',
  '중3',
  '고1',
  '고2',
  '고3',
  '성인',
];

class ProfileManageScreen extends ConsumerStatefulWidget {
  const ProfileManageScreen({super.key, required this.initialSettings});

  final UserSettingsModel initialSettings;

  @override
  ConsumerState<ProfileManageScreen> createState() =>
      _ProfileManageScreenState();
}

class _ProfileManageScreenState extends ConsumerState<ProfileManageScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _birthDateController;
  late String _listeningGradeLabel;
  late String _readingGradeLabel;
  late String _ageLabel;
  String? _avatarImagePath;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(profileUiPrefsProvider);
    final isStudent = widget.initialSettings.role == 'STUDENT';

    _nameController = TextEditingController(
      text: widget.initialSettings.displayName,
    );
    _schoolController = TextEditingController(text: prefs.schoolName);
    _birthDateController = TextEditingController(
      text: widget.initialSettings.birthDate.isEmpty
          ? prefs.birthDate
          : widget.initialSettings.birthDate,
    );
    final fallbackGrade = _gradeFromTrack(widget.initialSettings.track);
    _listeningGradeLabel = isStudent
        ? prefs.listeningGradeLabel
        : fallbackGrade;
    _readingGradeLabel = isStudent ? prefs.readingGradeLabel : fallbackGrade;
    _ageLabel = isStudent ? prefs.ageLabel : '성인';
    _avatarImagePath = prefs.avatarImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.initialSettings.role == 'STUDENT';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: IconButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE9EBF3),
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ),
        title: const Text('내 정보 관리'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
              child: Text(
                '수정',
                style: AppTypography.section.copyWith(color: AppColors.primary),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8EAF2),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _ProfileAvatarPreview(path: _avatarImagePath),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _isEditing && !_isSaving ? _pickProfileImage : null,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isEditing
                            ? AppColors.primary
                            : const Color(0xFFD9DDE8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.camera_alt_rounded
                            : Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _isEditing
                ? '프로필 이미지를 눌러 사진을 변경할 수 있어요.'
                : '수정 모드에서 프로필 이미지를 변경할 수 있어요.',
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('기본 정보', style: AppTypography.section),
          const SizedBox(height: AppSpacing.md),
          _LabelText(text: '이름'),
          const SizedBox(height: AppSpacing.xs),
          _InputShell(
            enabled: _isEditing,
            child: TextField(
              controller: _nameController,
              enabled: _isEditing && !_isSaving,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              maxLength: DbTextLimits.displayNameMax,
              decoration: const InputDecoration(
                hintText: '이름을 입력해 주세요.',
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              style: AppTypography.title.copyWith(
                fontSize: 43 / 2,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabelText(text: '생년월일(선택사항)'),
          const SizedBox(height: AppSpacing.xs),
          _InputShell(
            enabled: _isEditing,
            child: TextField(
              controller: _birthDateController,
              enabled: _isEditing && !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: const [BirthDateTextInputFormatter()],
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD (선택사항)',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              style: AppTypography.title.copyWith(
                fontSize: 43 / 2,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_birthDateController.text.trim().isNotEmpty &&
              !isValidBirthDateText(_birthDateController.text.trim())) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '생년월일 형식은 YYYY-MM-DD로 입력해 주세요.',
              style: AppTypography.label.copyWith(color: AppColors.danger),
            ),
          ],
          if (isStudent) ...[
            const SizedBox(height: AppSpacing.sm),
            _LabelText(text: '학교'),
            const SizedBox(height: AppSpacing.xs),
            _InputShell(
              enabled: _isEditing,
              child: TextField(
                controller: _schoolController,
                enabled: _isEditing && !_isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '학교를 입력해 주세요.',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                style: AppTypography.title.copyWith(
                  fontSize: 43 / 2,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabelText(text: '듣기 학습 학년'),
            const SizedBox(height: AppSpacing.xs),
            _SelectionShell(
              enabled: _isEditing,
              label: _listeningGradeLabel,
              onTap: !_isEditing || _isSaving
                  ? null
                  : () async {
                      final selected = await _showSimplePicker(
                        context,
                        title: '듣기 학습 학년 선택',
                        options: _learningGradeOptions,
                        selectedValue: _listeningGradeLabel,
                      );
                      if (selected == null ||
                          selected == _listeningGradeLabel) {
                        return;
                      }
                      setState(() {
                        _listeningGradeLabel = selected;
                      });
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabelText(text: '독해 학습 학년'),
            const SizedBox(height: AppSpacing.xs),
            _SelectionShell(
              enabled: _isEditing,
              label: _readingGradeLabel,
              onTap: !_isEditing || _isSaving
                  ? null
                  : () async {
                      final selected = await _showSimplePicker(
                        context,
                        title: '독해 학습 학년 선택',
                        options: _learningGradeOptions,
                        selectedValue: _readingGradeLabel,
                      );
                      if (selected == null || selected == _readingGradeLabel) {
                        return;
                      }
                      setState(() {
                        _readingGradeLabel = selected;
                      });
                    },
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabelText(text: '현재 학년'),
            const SizedBox(height: AppSpacing.xs),
            _SelectionShell(
              enabled: _isEditing,
              label: _ageLabel,
              onTap: !_isEditing || _isSaving
                  ? null
                  : () async {
                      final selected = await _showSimplePicker(
                        context,
                        title: '현재 학년 선택',
                        options: _ageOptions,
                        selectedValue: _ageLabel,
                      );
                      if (selected == null || selected == _ageLabel) {
                        return;
                      }
                      setState(() {
                        _ageLabel = selected;
                      });
                    },
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _LabelText(text: '사용자 유형'),
          const SizedBox(height: AppSpacing.xs),
          _SelectionShell(
            enabled: false,
            label: isStudent ? '학생' : '학부모',
            onTap: null,
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '유형은 첫 로그인에서 선택된 이후 변경할 수 없습니다.',
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _isEditing
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: PrimaryPillButton(
                  label: '완료',
                  onPressed: _isSaving ? null : _save,
                ),
              ),
            )
          : null,
    );
  }

  Future<String?> _showSimplePicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selectedValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(title, style: AppTypography.section),
                );
              }

              final value = options[index - 1];
              final selected = value == selectedValue;
              return ListTile(
                onTap: () => Navigator.of(context).pop(value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                tileColor: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                title: Text(value),
                trailing: selected
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemCount: options.length + 1,
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final isStudent = widget.initialSettings.role == 'STUDENT';
    final trimmedName = _nameController.text.trim();
    final trimmedSchool = _schoolController.text.trim();
    final trimmedBirthDate = _birthDateController.text.trim();

    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름을 입력해 주세요.')));
      return;
    }
    if (trimmedName.length > DbTextLimits.displayNameMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이름은 ${DbTextLimits.displayNameMax}자 이하로 입력해 주세요.'),
        ),
      );
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
      _isSaving = true;
    });

    try {
      final notifier = ref.read(userSettingsProvider.notifier);
      final mappedTrack = _mapGradeToTrack(_listeningGradeLabel);

      if (widget.initialSettings.displayName.trim() != trimmedName) {
        await notifier.updateName(trimmedName);
      }
      if (widget.initialSettings.birthDate != trimmedBirthDate) {
        await notifier.updateBirthDate(trimmedBirthDate);
      }
      if (isStudent && widget.initialSettings.track != mappedTrack) {
        await notifier.updateTrack(mappedTrack);
      }

      ref.read(profileUiPrefsProvider.notifier).state = ref
          .read(profileUiPrefsProvider)
          .copyWith(
            schoolName: isStudent
                ? (trimmedSchool.isEmpty ? '학교 미설정' : trimmedSchool)
                : '학부모 계정',
            listeningGradeLabel: isStudent ? _listeningGradeLabel : '고1',
            readingGradeLabel: isStudent ? _readingGradeLabel : '고1',
            ageLabel: isStudent ? _ageLabel : '성인',
            birthDate: trimmedBirthDate,
            avatarImagePath: _avatarImagePath,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내 정보가 저장되었습니다.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장에 실패했습니다.\n$error')));
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'images',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
          ),
        ],
      );
      if (file == null || file.path.isEmpty) {
        return;
      }

      setState(() {
        _avatarImagePath = file.path;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('이미지 선택에 실패했습니다.\n$error')));
    }
  }

  String _mapGradeToTrack(String grade) {
    switch (grade) {
      case '고1':
        return 'H1';
      case '고2':
        return 'H2';
      case '고3':
        return 'H3';
      case '중3':
      default:
        return 'M3';
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
        return '중3';
    }
  }
}

class _ProfileAvatarPreview extends StatelessWidget {
  const _ProfileAvatarPreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return const Icon(
        Icons.person_rounded,
        size: 70,
        color: Color(0xFF9EA2AD),
      );
    }

    final file = File(path!);
    if (!file.existsSync()) {
      return const Icon(
        Icons.person_rounded,
        size: 70,
        color: Color(0xFF9EA2AD),
      );
    }

    return ClipOval(
      child: Image.file(
        file,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.person_rounded,
            size: 70,
            color: Color(0xFF9EA2AD),
          );
        },
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: enabled ? const Color(0xFFC7CCE1) : const Color(0xFFD7DAE4),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class _SelectionShell extends StatelessWidget {
  const _SelectionShell({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F1F6),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFC7CCE1)
                  : const Color(0xFFD7DAE4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    fontSize: 43 / 2,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 30,
                color: enabled
                    ? const Color(0xFF8D91A1)
                    : const Color(0xFFC8CAD4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
