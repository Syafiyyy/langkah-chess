import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/tile_button.dart';
import '../application/online_game_view.dart';

/// Flip, Moves, Draw, and Abort (before both moved) or Resign: four tiles.
class OnlineControls extends StatelessWidget {
  const OnlineControls({
    super.key,
    required this.view,
    required this.onFlip,
    required this.onMoves,
    required this.onOfferDraw,
    required this.onAcceptDraw,
    required this.onAbort,
    required this.onResign,
  });

  final OnlineGameView view;
  final VoidCallback onFlip;
  final VoidCallback onMoves;
  final VoidCallback onOfferDraw;
  final VoidCallback onAcceptDraw;
  final VoidCallback onAbort;
  final VoidCallback onResign;

  Future<void> _confirmResign(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Resign this game?',
      message: 'Your opponent wins and the result is rated.',
      confirmLabel: 'Resign game',
      cancelLabel: 'Keep playing',
      destructive: true,
    );
    if (ok) onResign();
  }

  Future<void> _confirmAbort(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Abort this game?',
      message: 'Nobody wins and it is not rated.',
      confirmLabel: 'Abort game',
      cancelLabel: 'Keep playing',
      destructive: true,
    );
    if (ok) onAbort();
  }

  @override
  Widget build(BuildContext context) {
    final v = view;
    final active = v.game.isActive;
    final draw = v.opponentOffersDraw
        ? ('Accept draw', onAcceptDraw)
        : ('Offer draw', onOfferDraw);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: TileButton(
              icon: Icons.swap_vert_rounded,
              label: 'Flip',
              onPressed: onFlip,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TileButton(
              icon: Icons.format_list_numbered_rounded,
              label: 'Moves',
              onPressed: onMoves,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TileButton(
              icon: Icons.handshake_rounded,
              label: draw.$1,
              // Abort, not a draw, before both have moved.
              onPressed: active && !v.canAbort && !v.iOfferDraw
                  ? draw.$2
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: v.canAbort
                ? TileButton(
                    icon: Icons.close_rounded,
                    label: 'Abort',
                    destructive: true,
                    onPressed: () => _confirmAbort(context),
                  )
                : TileButton(
                    icon: Icons.flag_rounded,
                    label: 'Resign',
                    destructive: true,
                    onPressed: active ? () => _confirmResign(context) : null,
                  ),
          ),
        ],
      ),
    );
  }
}
