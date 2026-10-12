import 'package:dartchess/dartchess.dart';

/// Standard UCI for a legal [move] in [position]: castling is written as the
/// king's two-square move (`e1g1`), whether the board sent king-to-g1 or
/// king-onto-rook (`e1h1`), as the chess-domain rules require.
String standardUci(Position position, Move move) {
  if (move is! NormalMove) return move.uci;
  final piece = position.board.pieceAt(move.from);
  final target = position.board.pieceAt(move.to);
  final isCastleOntoRook =
      piece?.role == Role.king &&
      target?.role == Role.rook &&
      target?.color == piece?.color;
  if (!isCastleOntoRook) return move.uci;
  final file = move.to.file > move.from.file ? File.g : File.c;
  return NormalMove(from: move.from, to: Square.fromCoords(file, move.from.rank)).uci;
}
