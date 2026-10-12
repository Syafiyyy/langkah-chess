import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
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
  });

  final List<PositionEval> evals;
  final List<MoveReview> reviews;

  /// Total positions in the game (x axis length).
  final int positions;
  final int ply;
  final ValueChanged<int> onSelect;

  static const double height = 72;

  MoveLabel? _labelAt(int index) =>
      index >= 1 && index <= reviews.length ? reviews[index - 1].label : null;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < evals.length; i++)
        FlSpot(i.toDouble(), evals[i].whiteWin - 50),
    ];
    return SizedBox(
      height: height,
      child: ColoredBox(
        color: AppColors.surface,
        child: LineChart(
          duration: Duration.zero,
          LineChartData(
            minX: 0,
            maxX: (positions - 1).clamp(1, 1 << 30).toDouble(),
            minY: -50,
            maxY: 50,
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 50,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.line, strokeWidth: 1),
            ),
            extraLinesData: ExtraLinesData(
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
                  color: AppColors.text.withValues(alpha: 0.85),
                  applyCutOffY: true,
                ),
                aboveBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF3A3F3C),
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
      ),
    );
  }
}
