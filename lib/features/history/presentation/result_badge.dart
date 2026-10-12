import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_type.dart';
import '../domain/finished_game.dart';

/// W / L / D tile for a finished game, from the player's side.
class ResultBadge extends StatelessWidget {
  const ResultBadge(this.result, {super.key});

  final PlayerResult result;

  @override
  Widget build(BuildContext context) {
    final (letter, color, label) = switch (result) {
      PlayerResult.win => ('W', AppColors.success, 'Win'),
      PlayerResult.loss => ('L', AppColors.danger, 'Loss'),
      PlayerResult.draw => ('D', AppColors.textMuted, 'Draw'),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: const BorderRadius.all(AppRadius.md),
          border: Border.all(color: color),
        ),
        child: Text(letter, style: AppType.move.copyWith(color: color)),
      ),
    );
  }
}
