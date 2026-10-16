import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../domain/game_state.dart';

/// What the player chose on the game-over sheet.
enum GameOverAction { review, newGame, rematch, home }

/// What the sheet shows: [won] is true/false for a win/loss and null for a
/// draw (or an aborted game when [aborted]).
class GameOverInfo {
  const GameOverInfo({
    required this.title,
    required this.details,
    this.won,
    this.aborted = false,
    this.ratingChange,
  });

  /// An offline game against the bot.
  factory GameOverInfo.offline(GameState game) {
    final winner = game.result!.outcome.winner;
    final won = winner == null ? null : winner == game.playerSide;
    final moves = (game.moves.length + 1) ~/ 2;
    final duration = game.endedAt!.difference(game.startedAt);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return GameOverInfo(
      title: switch (won) {
        true => 'You won',
        false => 'You lost',
        null => 'Draw',
      },
      won: won,
      details:
          '${game.result!.reason} · $moves moves · '
          '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
    );
  }

  final String title;
  final String details;
  final bool? won;
  final bool aborted;

  /// Online rated games: the player's rating change.
  final int? ratingChange;
}

/// Result, reason, details and the next actions.
class GameOverSheet extends StatelessWidget {
  const GameOverSheet({
    super.key,
    required this.info,
    this.actions = const {
      GameOverAction.review: 'Review game',
      GameOverAction.rematch: 'Play rematch (swap colours)',
      GameOverAction.newGame: 'Start new game',
      GameOverAction.home: 'Go home',
    },
  });

  final GameOverInfo info;

  /// Buttons in order, with their labels. The first is the primary one; the
  /// last is a text button.
  final Map<GameOverAction, String> actions;

  /// The offline sheet for a finished game against the bot.
  static Future<GameOverAction?> show(BuildContext context, GameState game) =>
      showInfo(context, GameOverInfo.offline(game));

  static Future<GameOverAction?> showInfo(
    BuildContext context,
    GameOverInfo info, {
    Map<GameOverAction, String>? actions,
  }) {
    return showModalBottomSheet<GameOverAction>(
      context: context,
      showDragHandle: true,
      // Sized to its content (the default caps sheets at 9/16 of the screen).
      isScrollControlled: true,
      builder: (context) => actions == null
          ? GameOverSheet(info: info)
          : GameOverSheet(info: info, actions: actions),
    );
  }

  IconData get _icon => info.aborted
      ? Icons.block_rounded
      : switch (info.won) {
          true => Icons.emoji_events_rounded,
          false => Icons.flag_rounded,
          null => Icons.handshake_rounded,
        };

  Color get _iconColor =>
      info.won ?? false ? AppColors.success : AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    final change = info.ratingChange;
    final entries = actions.entries.toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_icon, color: _iconColor, size: 32),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: Text(info.title, style: AppType.headline)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(info.details, style: AppType.secondary),
            if (change != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Rating ${change >= 0 ? '+' : '−'}${change.abs()}',
                key: const ValueKey('rating-change'),
                style: AppType.label.copyWith(
                  color: change >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              _button(context, i, entries.length, entries[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    int index,
    int count,
    MapEntry<GameOverAction, String> entry,
  ) {
    void pop() => Navigator.pop(context, entry.key);
    final label = Text(entry.value);
    if (index == 0) return FilledButton(onPressed: pop, child: label);
    if (index == count - 1) return TextButton(onPressed: pop, child: label);
    return OutlinedButton(onPressed: pop, child: label);
  }
}
