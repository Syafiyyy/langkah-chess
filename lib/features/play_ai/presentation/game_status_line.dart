import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../application/play_ai_view.dart';
import '../domain/game_state.dart';

/// One line under the board: browsing, engine trouble, or the result.
class GameStatusLine extends StatelessWidget {
  const GameStatusLine({
    super.key,
    required this.view,
    required this.onBackToGame,
    required this.onRetry,
    required this.onShowResult,
  });

  final PlayAiView view;
  final VoidCallback onBackToGame;
  final VoidCallback onRetry;
  final VoidCallback onShowResult;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    final (
      String text,
      String? action,
      VoidCallback? onAction,
    ) = switch (view) {
      PlayAiView(isBrowsing: true) => (
        'Viewing an earlier position',
        'Return to game',
        onBackToGame,
      ),
      PlayAiView(engineFailed: true) => (
        'The bot did not answer.',
        'Retry',
        onRetry,
      ),
      PlayAiView(game: GameState(isOver: true, :final result?)) => (
        result.reason,
        'Show result',
        onShowResult,
      ),
      _ => ('', null, null),
    };
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(child: Text(text, style: AppType.secondary)),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
