import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/app_copy_ko.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/app_snackbars.dart';
import '../../family/application/family_providers.dart';
import '../../family/data/family_repository.dart';
import '../application/parent_ui_providers.dart';

Future<void> showNotificationInbox(
  BuildContext context,
  WidgetRef ref, {
  required bool isParent,
}) async {
  final items = isParent
      ? ref.read(parentNotificationItemsProvider)
      : ref.read(studentNotificationItemsProvider);

  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.mdLg,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.mdLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('알림함 🔔', style: AppTypography.title),
                  const Spacer(),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(color: AppColors.divider),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.title} ${item.emoji}',
                                  style: AppTypography.section,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                item.relativeTime,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.message,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showAddChildDialog(BuildContext context, WidgetRef ref) async {
  var inviteCodeInput = '';
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('자녀 추가하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('초대 코드 6자리를 입력해 주세요.'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (value) => inviteCodeInput = value,
                decoration: const InputDecoration(
                  hintText: '123456',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(familyLinksProvider.notifier)
        .consumeChildLinkCode(inviteCodeInput);
    final children = ref.read(parentLinkedChildrenProvider);
    final lastChild = children.isEmpty ? null : children.last;
    ref.read(selectedParentChildIdProvider.notifier).state = lastChild?.id;

    if (!context.mounted) {
      return;
    }
    AppSnackbars.showSuccess(context, AppCopyKo.parentChildAdded);
  } on FamilyRepositoryException catch (error) {
    if (!context.mounted) {
      return;
    }
    AppSnackbars.showWarning(context, _toFamilyLinkErrorMessage(error.code));
  } on FormatException {
    if (!context.mounted) {
      return;
    }
    AppSnackbars.showWarning(context, AppCopyKo.parentInviteCodeInvalid);
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    AppSnackbars.showError(context, AppCopyKo.parentChildAddFailed);
  }
}

String _toFamilyLinkErrorMessage(String code) {
  switch (code) {
    case 'invalid_link_code':
      return AppCopyKo.familyLinkInvalid;
    case 'link_code_expired':
      return AppCopyKo.familyLinkExpired;
    case 'link_code_already_consumed':
      return AppCopyKo.familyLinkAlreadyUsed;
    case 'child_parent_limit_reached':
      return AppCopyKo.familyLinkMaxParentsReached;
    case 'duplicate_active_link':
      return AppCopyKo.familyLinkDuplicate;
    case 'rate_limit_exceeded':
      return AppCopyKo.familyLinkRateLimited;
    case 'invalid_access_token':
    case 'invalid_refresh_token':
    case 'refresh_token_reuse_detected':
      return AppCopyKo.familyLinkSessionExpired;
    default:
      return AppCopyKo.parentChildAddFailed;
  }
}

Future<void> showParentChildManageSheet(
  BuildContext context,
  WidgetRef ref, {
  required ParentLinkedChild child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mdLg,
            AppSpacing.sm,
            AppSpacing.mdLg,
            AppSpacing.mdLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEDEFFE),
                    ),
                    child: const Icon(
                      Icons.face_2_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${child.displayName} 학생 관리',
                      style: AppTypography.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: Color(0xFF8F9094),
                      size: 34,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '무료 회원 사용 중',
                            style: AppTypography.section.copyWith(
                              color: const Color(0xFF66686D),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '프리미엄으로 무제한 학습하세요!',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        AppSnackbars.showWarning(context, '업그레이드 기능은 준비 중입니다.');
                      },
                      child: const Text('업그레이드'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ParentManageActionTile(
                icon: Icons.insert_chart_outlined_rounded,
                iconBgColor: const Color(0xFFDDEDFC),
                iconColor: const Color(0xFF2E8FE3),
                title: 'AI 학습 리포트 보기',
                onTap: () {
                  Navigator.of(context).pop();
                  AppSnackbars.showWarning(context, '리포트 상세 연결은 준비 중입니다.');
                },
              ),
              _ParentManageActionTile(
                icon: Icons.filter_none_rounded,
                iconBgColor: const Color(0xFFE8F4E8),
                iconColor: const Color(0xFF55AA5E),
                title: '변형 문제 확인',
                onTap: () {
                  Navigator.of(context).pop();
                  AppSnackbars.showWarning(context, '변형 문제 기능은 준비 중입니다.');
                },
              ),
              _ParentManageActionTile(
                icon: Icons.timer_outlined,
                iconBgColor: const Color(0xFFF1E6FB),
                iconColor: const Color(0xFF9A4DD7),
                title: '모의고사 성적표',
                onTap: () {
                  Navigator.of(context).pop();
                  AppSnackbars.showWarning(context, '성적표 화면 연결은 준비 중입니다.');
                },
              ),
              _ParentManageActionTile(
                icon: Icons.favorite_rounded,
                iconBgColor: const Color(0xFFFCE2ED),
                iconColor: const Color(0xFFD84585),
                title: '응원 메시지 보내기',
                onTap: () {
                  Navigator.of(context).pop();
                  AppSnackbars.showWarning(context, '응원 메시지 기능은 준비 중입니다.');
                },
              ),
              _ParentManageActionTile(
                icon: Icons.assignment_late_outlined,
                iconBgColor: const Color(0xFFFFEED8),
                iconColor: const Color(0xFFF09B2D),
                title: '오답노트 점검',
                onTap: () {
                  Navigator.of(context).pop();
                  AppSnackbars.showWarning(context, '오답노트 점검 기능은 준비 중입니다.');
                },
              ),
              const Divider(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AppSnackbars.showWarning(context, '자녀 연결 해지 기능은 준비 중입니다.');
                  },
                  child: Text(
                    '자녀 연결 해지하기',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ParentManageActionTile extends StatelessWidget {
  const _ParentManageActionTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: AppTypography.section),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
