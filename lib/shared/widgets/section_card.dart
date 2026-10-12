import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// An L1 surface: 1 px border, 14 px radius, no shadow. Tappable when
/// [onTap] is set. [selected] draws a gold border (theme cards).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(AppRadius.lg),
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
