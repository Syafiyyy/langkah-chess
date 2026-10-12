import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/app_sheet.dart';

/// All moves in numbered rows. Returns the tapped ply, or null.
Future<int?> showMovesSheet(
  BuildContext context, {
  required List<String> sans,
  required int selectedPly,
}) {
  return showAppSheet<int>(
    context,
    title: 'Moves',
    builder: (context) {
      if (sans.isEmpty) {
        return const Text('No moves yet.', style: AppType.secondary);
      }
      return Column(
        children: [
          for (var i = 0; i < sans.length; i += 2)
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('${i ~/ 2 + 1}.', style: AppType.meta),
                ),
                Expanded(child: _Move(sans[i], i + 1, selectedPly)),
                Expanded(
                  child: i + 1 < sans.length
                      ? _Move(sans[i + 1], i + 2, selectedPly)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      );
    },
  );
}

class _Move extends StatelessWidget {
  const _Move(this.san, this.ply, this.selectedPly);

  final String san;
  final int ply;
  final int selectedPly;

  @override
  Widget build(BuildContext context) {
    final selected = ply == selectedPly;
    return InkWell(
      borderRadius: const BorderRadius.all(AppRadius.sm),
      onTap: () => Navigator.pop(context, ply),
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceRaised : null,
          borderRadius: const BorderRadius.all(AppRadius.sm),
        ),
        child: Text(
          san,
          style: AppType.move.copyWith(
            color: selected ? AppColors.accent : AppColors.text,
          ),
        ),
      ),
    );
  }
}
