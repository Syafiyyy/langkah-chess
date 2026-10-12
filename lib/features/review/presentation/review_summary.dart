import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Side(
                key: const ValueKey('summary-white'),
                name: whiteName,
                summary: white,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _Side(
                key: const ValueKey('summary-black'),
                name: blackName,
                summary: black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({super.key, required this.name, required this.summary});

  final String name;
  final SideSummary summary;

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.accuracy;
    final counts = [
      (
        summary.inaccuracies,
        MoveLabel.inaccuracy,
        'Inaccuracy',
        'Inaccuracies',
      ),
      (summary.mistakes, MoveLabel.mistake, 'Mistake', 'Mistakes'),
      (summary.blunders, MoveLabel.blunder, 'Blunder', 'Blunders'),
    ].where((c) => c.$1 > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppType.secondary, overflow: TextOverflow.ellipsis),
        Text(
          accuracy == null ? '–' : '${accuracy.toStringAsFixed(1)}%',
          style: AppType.stat,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (accuracy != null && counts.isEmpty)
          const Text('No errors', style: AppType.secondary)
        else
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (n, label, one, many) in counts)
                _Count(text: '$n ${n == 1 ? one : many}', label: label),
            ],
          ),
      ],
    );
  }
}

/// A colour dot and a labelled count, e.g. "1 Blunder". Plain text, no
/// pill: it is static information.
class _Count extends StatelessWidget {
  const _Count({required this.text, required this.label});

  final String text;
  final MoveLabel label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: labelColor(label),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: AppType.secondary),
      ],
    );
  }
}
