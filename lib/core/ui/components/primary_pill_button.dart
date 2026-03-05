import 'package:flutter/material.dart';

import '../app_tokens.dart';

class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabledBackground = AppColors.primary.withValues(alpha: 0.38);
    final disabledForeground = Colors.white.withValues(alpha: 0.72);

    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: Size(expand ? double.infinity : 0, 56),
      backgroundColor: AppColors.primary,
      disabledBackgroundColor: disabledBackground,
      disabledForegroundColor: disabledForeground,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonPill),
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg),
    );
    final labelText = Text(
      label,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
    );

    if (leading == null) {
      return SizedBox(
        width: expand ? double.infinity : null,
        child: ElevatedButton(
          onPressed: onPressed,
          style: buttonStyle,
          child: labelText,
        ),
      );
    }

    return SizedBox(
      width: expand ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: buttonStyle,
        icon: leading!,
        label: labelText,
      ),
    );
  }
}
