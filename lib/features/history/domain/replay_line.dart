import 'package:dartchess/dartchess.dart';

/// Every position of a game, for stepping through it.
class ReplayLine {
  const ReplayLine({
    required this.fens,
    required this.sans,
    required this.lastMoves,
  });

  /// `fens[i]` is the position after `i` half-moves.
  final List<String> fens;
  final List<String> sans;

  /// `lastMoves[i]` is the move that led to `fens[i]` (null at the start).
  final List<Move?> lastMoves;
}

/// Replays the mainline of [pgn] with dartchess. Stops at the first move
/// that does not parse (a saved game should never have one).
ReplayLine replayPgn(String pgn) {
  final game = PgnGame.parsePgn(pgn);
  Position position = PgnGame.startingPosition(game.headers);
  final fens = [position.fen];
  final sans = <String>[];
  final lastMoves = <Move?>[null];
  for (final node in game.moves.mainline()) {
    final move = position.parseSan(node.san);
    if (move == null) break;
    position = position.play(move);
    fens.add(position.fen);
    sans.add(node.san);
    lastMoves.add(move);
  }
  return ReplayLine(fens: fens, sans: sans, lastMoves: lastMoves);
}
