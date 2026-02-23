import 'package:flutter/material.dart';

import '../app_copy_ko.dart';
import '../haptics.dart';

class AppSnackbars {
  const AppSnackbars._();

  static void showSuccess(
    BuildContext context,
    String message, {
    bool haptic = true,
  }) {
    _show(context, message: message, haptic: haptic ? Haptics.success : null);
  }

  static void showWarning(
    BuildContext context,
    String message, {
    bool haptic = true,
  }) {
    _show(context, message: message, haptic: haptic ? Haptics.warning : null);
  }

  static void showError(
    BuildContext context,
    String message, {
    bool haptic = true,
  }) {
    _show(context, message: message, haptic: haptic ? Haptics.warning : null);
  }

  static void showCanceled(
    BuildContext context, {
    String message = AppCopyKo.actionCanceled,
    bool haptic = false,
  }) {
    _show(context, message: message, haptic: haptic ? Haptics.warning : null);
  }

  static void _show(
    BuildContext context, {
    required String message,
    void Function()? haptic,
  }) {
    if (!context.mounted) {
      return;
    }
    haptic?.call();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
