import 'dart:math';

import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/game_state.dart';
import 'position_eval.dart';

/// Judgement of one move. No label means an ordinary, acceptable move.
enum MoveLabel {
  best('!', 'Best'),
  inaccuracy('?!', 'Inaccuracy'),
  mistake('?', 'Mistake'),
  blunder('??', 'Blunder');

  const MoveLabel(this.symbol, this.title);

  final String symbol;
  final String title;

  bool get isError => this != best;
}

/// Label for a move that took the mover's winning chance from [before] to
/// [after] (both 0..100, mover's view).
///
/// - The engine's own move is "best".
/// - Otherwise by the drop: >= 15 blunder, >= 10 mistake, >= 5 inaccuracy
///   (Lichess's 0.3 / 0.2 / 0.1 winning-chance thresholds).
/// - No error label when the game was already decided either way: the mover
///   stays >= 90% (still clearly winning) or stays <= 10% (already lost).
MoveLabel? labelFor(double before, double after, {required bool playedBest}) {
  if (playedBest) return MoveLabel.best;
  if ((before >= 90 && after >= 90) || (before <= 10 && after <= 10)) {
    return null;
  }
  final drop = before - after;
  if (drop >= 15) return MoveLabel.blunder;
  if (drop >= 10) return MoveLabel.mistake;
  if (drop >= 5) return MoveLabel.inaccuracy;
  return null;
}

/// Accuracy (0..100) of one move, Lichess's `AccuracyPercent.fromWinPercents`
/// (lila, modules/analyse): 100 without a drop; otherwise
/// `103.1668100711649 * exp(-0.04354415386753951 * drop) - 3.166924740191411`
/// plus Lichess's +1 "uncertainty bonus", clamped to 0..100.
double moveAccuracy(double before, double after) {
  if (after >= before) return 100;
  final drop = before - after;
  final raw =
      103.1668100711649 * exp(-0.04354415386753951 * drop) -
      3.166924740191411 +
      1;
  return raw.clamp(0, 100).toDouble();
}

/// Review of the move from position `ply - 1` to position `ply`.
class MoveReview {
  const MoveReview({
    required this.ply,
    required this.mover,
    required this.uci,
    required this.san,
    required this.winBefore,
    required this.winAfter,
    required this.accuracy,
    required this.label,
    required this.bestMove,
    required this.bestSan,
  });

  /// 1 = White's first move.
  final int ply;
  final Side mover;
  final String uci;
  final String san;

  /// Mover's winning chance before and after the move (0..100).
  final double winBefore;
  final double winAfter;
  final double accuracy;
  final MoveLabel? label;

  /// The engine's preferred move in the position before (UCI and SAN).
  final String? bestMove;
  final String? bestSan;
}

/// Reviews every move whose before and after positions are evaluated.
/// `positions.length == moves.length + 1`; [evals] may be shorter while the
/// analysis is still running.
List<MoveReview> reviewGame({
  required List<Position> positions,
  required List<MoveRecord> moves,
  required List<PositionEval> evals,
}) {
  final count = min(moves.length, evals.length - 1);
  return [
    for (var i = 0; i < count; i++)
      _review(i, positions[i], moves[i], evals[i], evals[i + 1]),
  ];
}

MoveReview _review(
  int i,
  Position before,
  MoveRecord move,
  PositionEval evalBefore,
  PositionEval evalAfter,
) {
  final mover = before.turn;
  final winBefore = evalBefore.winFor(mover);
  final winAfter = evalAfter.winFor(mover);
  final best = evalBefore.bestMove;
  final bestParsed = best == null ? null : Move.parse(best);
  return MoveReview(
    ply: i + 1,
    mover: mover,
    uci: move.uci,
    san: move.san,
    winBefore: winBefore,
    winAfter: winAfter,
    accuracy: moveAccuracy(winBefore, winAfter),
    label: labelFor(winBefore, winAfter, playedBest: best == move.uci),
    bestMove: best,
    bestSan: bestParsed != null && before.isLegal(bestParsed)
        ? before.makeSan(bestParsed).$2
        : null,
  );
}

/// One side's totals.
class SideSummary {
  const SideSummary({
    required this.accuracy,
    required this.inaccuracies,
    required this.mistakes,
    required this.blunders,
  });

  /// Plain mean of the side's move accuracies; null with no moves yet.
  /// (Lichess averages a volatility-weighted and a harmonic mean instead.)
  final double? accuracy;
  final int inaccuracies;
  final int mistakes;
  final int blunders;
}

SideSummary summarise(List<MoveReview> reviews, Side side) {
  final own = reviews.where((r) => r.mover == side).toList();
  int count(MoveLabel l) => own.where((r) => r.label == l).length;
  return SideSummary(
    accuracy: own.isEmpty
        ? null
        : own.map((r) => r.accuracy).reduce((a, b) => a + b) / own.length,
    inaccuracies: count(MoveLabel.inaccuracy),
    mistakes: count(MoveLabel.mistake),
    blunders: count(MoveLabel.blunder),
  );
}
