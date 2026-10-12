import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../domain/game_state.dart';

/// What the player chose on the game-over sheet.
enum GameOverAction { review, newGame, rematch, home }

/// Result, reason, move count and duration, plus the next actions.
class GameOverSheet extends StatelessWidget {
  const GameOverSheet({super.key, required this.game});

  final GameState game;

  static Future<GameOverAction?> show(BuildContext context, GameState game) {
    return showModalBottomSheet<GameOverAction>(
      context: context,
      showDragHandle: true,
      // Sized to its content (the default caps sheets at 9/16 of the screen).
      isScrollControlled: true,
      builder: (context) => GameOverSheet(game: game),
    );
  }

  String get _title {
    final winner = game.result!.outcome.winner;
    if (winner == null) return 'Draw';
    return winner == game.playerSide ? 'You won' : 'You lost';
  }

  String get _details {
    final moves = (game.moves.length + 1) ~/ 2;
    final duration = game.endedAt!.difference(game.startedAt);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${game.result!.reason} · $moves moves · '
        '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
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
            Text(_title, style: AppType.display),
            const SizedBox(height: AppSpacing.xs),
            Text(_details, style: AppType.body),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, GameOverAction.review),
              child: const Text('Review game'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, GameOverAction.rematch),
              child: const Text('Rematch (swap colours)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, GameOverAction.newGame),
              child: const Text('New game'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, GameOverAction.home),
              child: const Text('Home'),
            ),
          ],
        ),
      ),
    );
  }
}
