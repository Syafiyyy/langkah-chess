import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_type.dart';

/// Builds the app's dark theme from the design tokens.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    // Selected chips and segments use the accent, not Material's default.
    secondaryContainer: AppColors.accent,
    onSecondaryContainer: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    outline: AppColors.line,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      titleTextStyle: AppType.title,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineMedium: AppType.display,
      titleLarge: AppType.title,
      bodyMedium: AppType.body,
      labelLarge: AppType.label,
      bodySmall: AppType.caption,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        textStyle: AppType.label,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        textStyle: AppType.label,
        side: const BorderSide(color: AppColors.line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(AppRadius.md),
        ),
      ),
    ),
  );
}
