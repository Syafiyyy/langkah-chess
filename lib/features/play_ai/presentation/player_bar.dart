import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../domain/chess_clock.dart';
import 'clock_text.dart';

/// A player's row above or below the board: name, status and clock.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.name,
    required this.side,
    required this.clock,
    this.thinking = false,
  });

  /// Fixed height, so the game screen can size the board around two bars.
  static const double height = 56;

  final String name;
  final Side side;

  /// Null for untimed games.
  final ChessClock? clock;

  /// Shows a quiet "Thinking…" with a small spinner under the name.
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final clock = this.clock;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: side == Side.white ? AppColors.text : AppColors.ground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppType.label,
                  overflow: TextOverflow.ellipsis,
                ),
                if (thinking) const _Thinking(),
              ],
            ),
          ),
          if (clock != null) ClockText(clock: clock, side: side),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(width: AppSpacing.xs + 2),
        Text('Thinking…', style: AppType.secondary),
      ],
    );
  }
}
