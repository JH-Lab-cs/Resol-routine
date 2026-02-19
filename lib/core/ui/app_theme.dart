import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      secondaryContainer: Color(0xFFDCD8FF),
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: Color(0xFF4A87D8),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD6E7FF),
      onTertiaryContainer: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFFF9D6DA),
      onErrorContainer: AppColors.textPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: Color(0xFFECEFF8),
      shadow: Color(0x19000000),
      scrim: Color(0x73000000),
      inverseSurface: Color(0xFF2A2B34),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFB8AEFF),
      surfaceTint: AppColors.primary,
    );

    final baseTextTheme = ThemeData.light(useMaterial3: true).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme.copyWith(
        displaySmall: AppTypography.display,
        headlineSmall: AppTypography.title,
        titleMedium: AppTypography.section,
        bodyMedium: AppTypography.body,
        labelLarge: AppTypography.label,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 1.5,
        shadowColor: Color(0x1A1E2546),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: const StadiumBorder(),
          textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
