import 'package:dartchess/dartchess.dart';

import '../../history/domain/finished_game.dart';
import '../domain/game_line.dart';
import '../domain/move_review.dart';
import '../domain/position_eval.dart';

/// What the review screen renders.
class ReviewState {
  const ReviewState({
    this.game,
    this.line,
    this.evals = const [],
    this.reviews = const [],
    this.ply = 0,
    this.analysing = false,
    this.failed = false,
    this.notFound = false,
  });

  /// Null while loading.
  final FinishedGame? game;
  final GameLine? line;

  /// One per position, filled from the start while analysing.
  final List<PositionEval> evals;

  /// One per move whose before/after positions are evaluated.
  final List<MoveReview> reviews;

  /// The position shown: 0 = start, n = after move n.
  final int ply;
  final bool analysing;

  /// The analysis stopped with an error; the screen offers a retry.
  final bool failed;
  final bool notFound;

  int get lastPly => line?.moves.length ?? 0;

  /// Positions analysed so far, of all positions.
  int get progress => evals.length;
  int get total => line?.positions.length ?? 0;

  SideSummary summary(Side side) => summarise(reviews, side);

  /// Review of the move that led to [ply], if known.
  MoveReview? reviewAt(int ply) =>
      ply >= 1 && ply <= reviews.length ? reviews[ply - 1] : null;

  ReviewState copyWith({
    FinishedGame? game,
    GameLine? line,
    List<PositionEval>? evals,
    List<MoveReview>? reviews,
    int? ply,
    bool? analysing,
    bool? failed,
    bool? notFound,
  }) => ReviewState(
    game: game ?? this.game,
    line: line ?? this.line,
    evals: evals ?? this.evals,
    reviews: reviews ?? this.reviews,
    ply: ply ?? this.ply,
    analysing: analysing ?? this.analysing,
    failed: failed ?? this.failed,
    notFound: notFound ?? this.notFound,
  );
}
