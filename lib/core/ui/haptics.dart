import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void warning() {
    HapticFeedback.lightImpact();
  }
}
