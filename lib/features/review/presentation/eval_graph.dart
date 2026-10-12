import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/move_review.dart';
import '../domain/position_eval.dart';
import 'review_style.dart';

/// White's winning chance over the game (above the middle: White better).
/// Fills in as the analysis runs; the x axis always spans the whole game.
/// Mistakes and blunders are dotted in their colour. Tap or drag to jump.
class EvalGraph extends StatelessWidget {
  const EvalGraph({
    super.key,
    required this.evals,
    required this.reviews,
    required this.positions,
    required this.ply,
    required this.onSelect,
    this.height = EvalGraph.fullHeight,
  });

  final List<PositionEval> evals;
  final List<MoveReview> reviews;

  /// Total positions in the game (x axis length).
  final int positions;
  final int ply;
  final ValueChanged<int> onSelect;

  /// Height on a normal phone; [compactHeight] when space is short.
  static const double fullHeight = 128;
  static const double compactHeight = 72;

  final double height;

  MoveLabel? _labelAt(int index) =>
      index >= 1 && index <= reviews.length ? reviews[index - 1].label : null;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < evals.length; i++)
        FlSpot(i.toDouble(), evals[i].whiteWin - 50),
    ];
    // An L1 card on the 16 px gutter, like the move strip below it.
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(AppRadius.md),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: 0,
          maxX: (positions - 1).clamp(1, 1 << 30).toDouble(),
          minY: -50,
          maxY: 50,
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          extraLinesData: ExtraLinesData(
            // Midline: equal chances. Drawn over the fills.
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: AppColors.textMuted.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ],
            verticalLines: [
              VerticalLine(
                x: ply.toDouble(),
                color: AppColors.accent,
                strokeWidth: 1.5,
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: false,
            touchCallback: (event, response) {
              final x = response?.lineBarSpots?.firstOrNull?.x;
              if (x != null && event.isInterestedForInteractions) {
                onSelect(x.round());
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
              color: AppColors.textMuted,
              barWidth: 1.5,
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.evalWhite.withValues(alpha: 0.85),
                applyCutOffY: true,
              ),
              aboveBarData: BarAreaData(
                show: true,
                color: AppColors.evalBlack,
                applyCutOffY: true,
              ),
              dotData: FlDotData(
                checkToShowDot: (spot, _) {
                  final label = _labelAt(spot.x.round());
                  return label == MoveLabel.mistake ||
                      label == MoveLabel.blunder;
                },
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: labelColor(_labelAt(spot.x.round())!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
