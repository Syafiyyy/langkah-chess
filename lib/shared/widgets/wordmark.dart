import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_type.dart';

/// The gold rhombus mark (a square turned 45°).
class DiamondMark extends StatelessWidget {
  const DiamondMark({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: SizedBox.square(
        dimension: size,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.all(Radius.circular(1.5)),
          ),
        ),
      ),
    );
  }
}

/// "◆ Skak" in Sora 700.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.style = AppType.wordmark});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? AppType.s20;
    return Semantics(
      label: kAppName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DiamondMark(size: size * 0.45),
          const SizedBox(width: AppSpacing.sm),
          Text(kAppName, style: style),
        ],
      ),
    );
  }
}
