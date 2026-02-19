import 'package:flutter/material.dart';

import '../app_tokens.dart';

class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: const StadiumBorder(),
    );
    final labelText = Text(
      label,
      style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
    );

    if (leading == null) {
      return ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: labelText,
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: buttonStyle,
      icon: leading!,
      label: labelText,
    );
  }
}
