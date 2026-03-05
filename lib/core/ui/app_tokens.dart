import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF4F6FF);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF5B61F5);
  static const Color primaryContainer = Color(0xFFE8EAFF);
  static const Color secondary = Color(0xFF7B80FF);
  static const Color onPrimary = Colors.white;
  static const Color textPrimary = Color(0xFF151A2D);
  static const Color textSecondary = Color(0xFF5A627A);
  static const Color border = Color(0xFFE3E7F7);
  static const Color divider = Color(0xFFE8ECFA);
  static const Color success = Color(0xFF1F8A49);
  static const Color warning = Color(0xFFF2A23D);
  static const Color streak = Color(0xFFF2A23D);
  static const Color danger = Color(0xFFBF2F3E);
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double mdLg = 20;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  const AppRadius._();

  static const double md = 16;
  static const double lg = 20;
  static const double card = 24;
  static const double xl = 32;
  static const double buttonPill = 30;
  static const double sheet = 32;
  static const double pill = 999;
}

class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x1211182F),
      blurRadius: 28,
      spreadRadius: -10,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x16131E4D),
      blurRadius: 36,
      spreadRadius: -12,
      offset: Offset(0, 16),
    ),
  ];
}

class AppTypography {
  const AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 1.14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
  );

  static const TextStyle section = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
}
