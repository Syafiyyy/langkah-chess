import 'dart:math' as math;

/// Winning chance (0..100) for the side the score belongs to, using the
/// Lichess formula: `50 + 50 * (2 / (1 + exp(-0.00368208 * cp)) - 1)`.
/// A mate score counts as 100 (mating) or 0 (getting mated).
double winPercent({int? cp, int? mate}) {
  if (mate != null) return mate > 0 ? 100 : 0;
  final c = cp ?? 0;
  return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * c)) - 1);
}
