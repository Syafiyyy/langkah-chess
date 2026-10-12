import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// Flip, takeback and resign. Resign asks for confirmation first.
class GameControls extends StatelessWidget {
  const GameControls({
    super.key,
    required this.onFlip,
    required this.onTakeback,
    required this.onResign,
  });

  final VoidCallback onFlip;

  /// Null disables takeback.
  final VoidCallback? onTakeback;

  /// Null disables resign (game over).
  final VoidCallback? onResign;

  Future<void> _confirmResign(BuildContext context) async {
    final resign = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        content: const Text('The bot wins and the game is saved to history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (resign ?? false) onResign?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _Control(icon: Icons.swap_vert, label: 'Flip', onPressed: onFlip),
          _Control(icon: Icons.undo, label: 'Takeback', onPressed: onTakeback),
          _Control(
            icon: Icons.flag_outlined,
            label: 'Resign',
            onPressed: onResign == null ? null : () => _confirmResign(context),
          ),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.icon, required this.label, this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Equal share of the row, label under the icon: fits 360 dp phones.
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
