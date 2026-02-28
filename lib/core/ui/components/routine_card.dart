import 'package:flutter/material.dart';

import '../app_tokens.dart';

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.maxHeight < 132 || constraints.maxWidth < 148;
            final padding = isCompact ? AppSpacing.md : AppSpacing.mdLg;
            final iconSize = isCompact ? 34.0 : 42.0;
            final iconInnerSize = isCompact ? 20.0 : 22.0;
            final gapAfterIcon = isCompact ? AppSpacing.sm : AppSpacing.mdLg;
            final gapBetweenTexts = isCompact ? AppSpacing.xxs : AppSpacing.xs;

            return Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primary,
                      size: iconInnerSize,
                    ),
                  ),
                  SizedBox(height: gapAfterIcon),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: isCompact ? 15 : 16,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gapBetweenTexts),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: isCompact ? 12 : 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
