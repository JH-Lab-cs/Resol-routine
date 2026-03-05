import 'package:flutter/material.dart';

import '../app_tokens.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailingWidgets = trailing == null ? null : <Widget>[trailing!];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.section),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...?trailingWidgets,
      ],
    );
  }
}
