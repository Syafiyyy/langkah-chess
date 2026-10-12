import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_type.dart';

/// A clock face. The running clock is gold; low time turns the digits to
/// the danger colour (on the inactive chip) or adds a danger border.
class ClockChip extends StatelessWidget {
  const ClockChip({
    super.key,
    required this.text,
    required this.active,
    this.low = false,
  });

  final String text;
  final bool active;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final fg = active
        ? AppColors.onAccent
        : low
        ? AppColors.danger
        : AppColors.textMuted;
    // Instant switch (colour is not an allowed animated property).
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.surfaceRaised,
        borderRadius: const BorderRadius.all(AppRadius.sm),
        border: Border.all(
          color: active && low ? AppColors.danger : AppColors.border,
          width: active && low ? 2 : 1,
        ),
      ),
      child: Text(text, style: AppType.clock.copyWith(color: fg)),
    );
  }
}
