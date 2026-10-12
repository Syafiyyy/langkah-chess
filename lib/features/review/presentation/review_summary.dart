import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../domain/move_review.dart';
import 'review_style.dart';

/// Accuracy and error counts for both sides.
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.whiteName,
    required this.blackName,
    required this.white,
    required this.black,
  });

  final String whiteName;
  final String blackName;
  final SideSummary white;
  final SideSummary black;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Side(name: whiteName, summary: white),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _Side(name: blackName, summary: black),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.name, required this.summary});

  final String name;
  final SideSummary summary;

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.accuracy;
    TextSpan count(int n, MoveLabel label) => TextSpan(
      text: '$n${label.symbol}  ',
      style: TextStyle(color: n == 0 ? AppColors.textMuted : labelColor(label)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppType.secondary, overflow: TextOverflow.ellipsis),
        Text(
          accuracy == null ? '–' : '${accuracy.toStringAsFixed(1)}%',
          style: AppType.title,
        ),
        Text.rich(
          TextSpan(
            children: [
              count(summary.inaccuracies, MoveLabel.inaccuracy),
              count(summary.mistakes, MoveLabel.mistake),
              count(summary.blunders, MoveLabel.blunder),
            ],
          ),
          style: AppType.secondary,
        ),
      ],
    );
  }
}
