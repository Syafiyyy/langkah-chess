import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/tile_button.dart';

/// Takeback, Flip, Moves, Resign: four 60 px tiles. Resign asks first.
class GameControls extends StatelessWidget {
  const GameControls({
    super.key,
    required this.onTakeback,
    required this.onFlip,
    required this.onMoves,
    required this.onResign,
  });

  /// Null disables the tile.
  final VoidCallback? onTakeback;
  final VoidCallback onFlip;
  final VoidCallback onMoves;
  final VoidCallback? onResign;

  Future<void> _confirmResign(BuildContext context) async {
    final resign = await showConfirmDialog(
      context,
      title: 'Resign this game?',
      message: 'The bot wins and the game is saved to history.',
      confirmLabel: 'Resign game',
      cancelLabel: 'Keep playing',
      destructive: true,
    );
    if (resign) onResign?.call();
  }

  @override
  Widget build(BuildContext context) {
    final onResign = this.onResign;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: TileButton(
              icon: Icons.undo_rounded,
              label: 'Takeback',
              onPressed: onTakeback,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
              icon: Icons.flag_rounded,
              label: 'Resign',
              destructive: true,
              onPressed: onResign == null
                  ? null
                  : () => _confirmResign(context),
            ),
          ),
        ],
      ),
    );
  }
}
