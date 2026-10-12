import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_type.dart';

/// The fixed "Songket" theme (dark only), built from the tokens.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.accent,
    onSecondary: AppColors.onAccent,
    secondaryContainer: AppColors.accent,
    onSecondaryContainer: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerHighest: AppColors.surfaceRaised,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.danger,
    onError: AppColors.onAccent,
  );
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(AppRadius.md),
  );
  const minButton = Size(48, 48);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppType.fontUi,
    scaffoldBackgroundColor: AppColors.ground,
    canvasColor: AppColors.ground,
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppType.heading,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: const TextTheme(
      headlineMedium: AppType.headline,
      titleLarge: AppType.title,
      titleMedium: AppType.subtitle,
      bodyLarge: AppType.body,
      bodyMedium: AppType.body,
      bodySmall: AppType.secondary,
      labelLarge: AppType.label,
      labelSmall: AppType.meta,
    ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 24),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            disabledBackgroundColor: AppColors.surfaceRaised,
            disabledForegroundColor: AppColors.textFaint,
            textStyle: AppType.label,
            minimumSize: minButton,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: buttonShape,
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? AppColors.surfaceRaised
                  : s.contains(WidgetState.pressed)
                  ? AppColors.accentPressed
                  : AppColors.accent,
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        textStyle: AppType.label,
        minimumSize: minButton,
        side: const BorderSide(color: AppColors.border),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppType.label,
        minimumSize: minButton,
        shape: buttonShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        disabledForegroundColor: AppColors.textFaint,
        minimumSize: minButton,
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accent,
      labelStyle: AppType.label,
      secondaryLabelStyle: TextStyle(
        fontFamily: AppType.fontUi,
        fontSize: AppType.s15,
        fontWeight: FontWeight.w500,
        color: AppColors.onAccent,
      ),
      side: BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        selectedBackgroundColor: AppColors.accent,
        selectedForegroundColor: AppColors.onAccent,
        side: const BorderSide(color: AppColors.border),
        textStyle: AppType.label,
        minimumSize: minButton,
        shape: buttonShape,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppType.heading,
      contentTextStyle: AppType.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.lg),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      textStyle: AppType.label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.md),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: AppType.body,
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textMuted,
      titleTextStyle: AppType.label,
      subtitleTextStyle: AppType.secondary,
      minVerticalPadding: AppSpacing.md,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.border,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.all(AppRadius.sm),
      ),
      textStyle: AppType.meta,
    ),
  );
}
