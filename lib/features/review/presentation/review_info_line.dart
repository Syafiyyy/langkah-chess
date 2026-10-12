import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../application/review_state.dart';
import 'review_style.dart';

/// One line under the board: the current move and its verdict ("12... Nf6??
/// Blunder · best Nc3") with the score, or the analysis progress.
class ReviewInfoLine extends StatelessWidget {
  const ReviewInfoLine({super.key, required this.state, required this.onRetry});

  final ReviewState state;
  final VoidCallback onRetry;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final ply = state.ply;
    final review = state.reviewAt(ply);
    final eval = ply < state.evals.length ? state.evals[ply] : null;
    final line = state.line!;

    final InlineSpan move;
    if (ply == 0) {
      move = const TextSpan(text: 'Start position');
    } else {
      final m = line.moves[ply - 1];
      final number = '${(ply + 1) ~/ 2}${ply.isOdd ? '.' : '...'}';
      final label = review?.label;
      move = TextSpan(
        text: '$number ${m.san}',
        children: [
          if (label != null)
            TextSpan(
              text: '${label.isError ? label.symbol : ''}  ${label.title}',
              style: TextStyle(color: labelColor(label)),
            ),
          if (review != null &&
              (label?.isError ?? false) &&
              review.bestSan != null)
            TextSpan(
              text: ' · best ${review.bestSan}',
              style: const TextStyle(color: AppColors.textMuted),
            ),
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                move,
                style: AppType.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state.failed)
              TextButton(onPressed: onRetry, child: const Text('Retry'))
            else if (state.analysing)
              _Progress(done: state.progress, total: state.total)
            else if (eval != null)
              Text(evalText(eval), style: AppType.label),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          child: LinearProgressIndicator(
            value: total == 0 ? null : done / total,
            minHeight: 3,
            color: AppColors.accent,
            backgroundColor: AppColors.line,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('Analysing $done/$total', style: AppType.caption),
      ],
    );
  }
}
