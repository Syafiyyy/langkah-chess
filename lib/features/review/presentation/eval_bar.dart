import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';

/// Vertical evaluation bar beside the board. White's share grows from the
/// side White plays from ([orientation]) and animates between plies.
class EvalBar extends StatelessWidget {
  const EvalBar({
    super.key,
    required this.whiteWin,
    required this.height,
    required this.orientation,
  });

  /// White's winning chance 0..100; null (not analysed yet) shows 50/50.
  final double? whiteWin;
  final double height;
  final Side orientation;

  static const double width = 14;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(AppRadius.sm),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: const Color(0xFF3A3F3C),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (whiteWin ?? 50) / 100),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, share, _) => Align(
              alignment: orientation == Side.white
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: share,
                widthFactor: 1,
                child: const ColoredBox(color: AppColors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
