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
    this.status,
  });

  final String name;
  final Side side;

  /// Null for untimed games.
  final ChessClock? clock;

  /// Small text under the name, e.g. "Thinking…".
  final String? status;

  @override
  Widget build(BuildContext context) {
    final clock = this.clock;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: side == Side.white ? AppColors.text : AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppType.label,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status != null) Text(status!, style: AppType.caption),
              ],
            ),
          ),
          if (clock != null) ClockText(clock: clock, side: side),
        ],
      ),
    );
  }
}
