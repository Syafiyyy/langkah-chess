import 'package:dartchess/dartchess.dart';

/// Why a game ended.
enum Termination {
  checkmate,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  seventyFiveMoveRule,
  resignation,
  timeout,

  /// Online only: both players agreed to a draw.
  agreement;

  /// Short human label, e.g. "Checkmate".
  String get label => switch (this) {
    checkmate => 'Checkmate',
    stalemate => 'Stalemate',
    insufficientMaterial => 'Insufficient material',
    threefoldRepetition => 'Threefold repetition',
    seventyFiveMoveRule => '75-move rule',
    resignation => 'Resignation',
    timeout => 'Timeout',
    agreement => 'Draw by agreement',
  };
}

/// Final result: who won (or draw) and why.
class GameResult {
  const GameResult(this.outcome, this.termination);

  final Outcome outcome;
  final Termination termination;

  /// e.g. "Timeout vs insufficient material" for a drawn timeout.
  String get reason =>
      termination == Termination.timeout && outcome == Outcome.draw
      ? 'Timeout vs insufficient material'
      : termination.label;
}

/// Identity of a position for repetition: placement, side to move, castling
/// rights and the en-passant square (only when a capture is legal, which
/// dartchess's `Position.fen` already ensures). Counters are ignored.
String positionKey(Position position) =>
    position.fen.split(' ').take(4).join(' ');

/// Result of the game once [position] is reached, or null if it goes on.
///
/// [repetitions] is how many times [position]'s [positionKey] has occurred,
/// including now. Draws by threefold repetition and by the 75-move rule are
/// automatic (no claim needed). Checkmate takes priority over both.
GameResult? resultAfterMove(Position position, {required int repetitions}) {
  if (position.isCheckmate) {
    return GameResult(
      Outcome(winner: position.turn.opposite),
      Termination.checkmate,
    );
  }
  if (position.isStalemate) {
    return const GameResult(Outcome.draw, Termination.stalemate);
  }
  if (position.isInsufficientMaterial) {
    return const GameResult(Outcome.draw, Termination.insufficientMaterial);
  }
  if (position.halfmoves >= 150) {
    return const GameResult(Outcome.draw, Termination.seventyFiveMoveRule);
  }
  if (repetitions >= 3) {
    return const GameResult(Outcome.draw, Termination.threefoldRepetition);
  }
  return null;
}

/// Result when [flagged] runs out of time: the other side wins, unless the
/// other side has insufficient mating material, which is a draw.
GameResult timeoutResult(Position position, Side flagged) {
  final opponent = flagged.opposite;
  final outcome = position.hasInsufficientMaterial(opponent)
      ? Outcome.draw
      : Outcome(winner: opponent);
  return GameResult(outcome, Termination.timeout);
}
