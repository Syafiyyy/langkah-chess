import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_type.dart';
import 'thinking_dots.dart';

/// A player's row above or below the board: avatar tile, name, a status line
/// (or "Thinking…"), and an optional clock.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.name,
    required this.side,
    this.subtitle,
    this.isBot = false,
    this.thinking = false,
    this.clock,
  });

  final String name;
  final Side side;

  /// e.g. "Level 3 · Casual".
  final String? subtitle;
  final bool isBot;

  /// Replaces the subtitle with animated "Thinking…".
  final bool thinking;

  /// Usually a ClockChip; null for untimed games.
  final Widget? clock;

  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            _Avatar(isBot: isBot, side: side),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppType.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (thinking)
                    const ThinkingDots()
                  else if (sub != null)
                    Text(
                      sub,
                      style: AppType.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?clock,
          ],
        ),
      ),
    );
  }
}

/// Avatar tile: a bot glyph or a person glyph, with a dot in the player's
/// piece colour.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.isBot, required this.side});

  final bool isBot;
  final Side side;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.all(AppRadius.md),
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              size: 22,
              color: AppColors.textMuted,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: side == Side.white ? AppColors.text : AppColors.ground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
