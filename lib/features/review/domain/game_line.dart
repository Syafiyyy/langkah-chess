import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/game_state.dart';
import '../../play_ai/domain/uci_move.dart';

/// The mainline of a saved game as positions and moves, for review.
class GameLine {
  const GameLine({required this.positions, required this.moves});

  /// Replays the mainline of [pgn] with dartchess. Stops at the first move
  /// that does not parse (a saved game never has one).
  factory GameLine.fromPgn(String pgn) {
    final game = PgnGame.parsePgn(pgn);
    final positions = <Position>[PgnGame.startingPosition(game.headers)];
    final moves = <MoveRecord>[];
    for (final node in game.moves.mainline()) {
      final before = positions.last;
      final move = before.parseSan(node.san);
      if (move == null) break;
      final (after, san) = before.makeSan(move);
      positions.add(after);
      moves.add(MoveRecord(uci: standardUci(before, move), san: san));
    }
    return GameLine(positions: positions, moves: moves);
  }

  /// `positions.length == moves.length + 1`.
  final List<Position> positions;
  final List<MoveRecord> moves;
}
