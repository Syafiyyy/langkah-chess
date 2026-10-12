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
    this.subtitle,
    this.isBot = false,
    this.thinking = false,
    this.toMove = false,
    this.clock,
  });

  final String name;

  /// e.g. "Level 3 · Bot".
  final String? subtitle;
  final bool isBot;

  /// Replaces the subtitle with animated "Thinking…".
  final bool thinking;

  /// Draws the gold side-to-move dot on the avatar.
  final bool toMove;

  /// Usually a ClockChip; null for untimed games.
  final Widget? clock;

  static const double height = 48;

  /// The side-to-move dot (for tests).
  static const toMoveKey = ValueKey('to-move');

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            _Avatar(isBot: isBot, toMove: toMove),
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

/// Avatar tile: a bot glyph or a person glyph; a gold dot when it is this
/// player's turn.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.isBot, required this.toMove});

  final bool isBot;
  final bool toMove;

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
          if (toMove)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                key: PlayerBar.toMoveKey,
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  // Ground ring separates the dot from the tile edge.
                  border: Border.all(color: AppColors.ground, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
