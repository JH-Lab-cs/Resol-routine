import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF3F5FA);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF6153D8);
  static const Color primaryContainer = Color(0xFFE2DEFF);
  static const Color secondary = Color(0xFF7E71E8);
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = Color(0xFF1B1B26);
  static const Color textSecondary = Color(0xFF5A5D73);
  static const Color border = Color(0xFFE4E7F2);
  static const Color success = Color(0xFF1F8A49);
  static const Color warning = Color(0xFFC77416);
  static const Color danger = Color(0xFFBF2F3E);
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  const AppRadius._();

  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

class AppTypography {
  const AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 30,
    height: 1.18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle section = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}
