import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

/// Interactive chessground board driven by a dartchess position.
///
/// The board only renders [position]; moves go out through [onMove] and come
/// back as a new [position]. Premoves are off. Promotion uses chessground's
/// own piece picker.
class GameBoard extends StatefulWidget {
  const GameBoard({
    super.key,
    required this.size,
    required this.position,
    required this.lastMove,
    required this.orientation,
    required this.interactiveSide,
    required this.onMove,
  });

  final double size;
  final Position position;
  final Move? lastMove;
  final Side orientation;

  /// The side that may move now, or null when the board is locked.
  final Side? interactiveSide;
  final void Function(Move move) onMove;

  static const settings = ChessboardSettings(
    colorScheme: ChessboardColorScheme.green,
    enablePremoves: false,
    enablePremoveCastling: false,
  );

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late final ChessboardController _controller = ChessboardController(
    game: _data(),
  );

  GameData _data() {
    final p = widget.position;
    final side = widget.interactiveSide;
    return GameData(
      fen: p.fen,
      lastMove: widget.lastMove,
      playerSide: switch (side) {
        Side.white => PlayerSide.white,
        Side.black => PlayerSide.black,
        null => PlayerSide.none,
      },
      sideToMove: p.turn,
      validMoves: side == null ? const {} : makeLegalMoves(p),
      kingSquareInCheck: p.isCheck ? p.board.kingOf(p.turn) : null,
    );
  }

  @override
  void didUpdateWidget(GameBoard old) {
    super.didUpdateWidget(old);
    if (old.position.fen != widget.position.fen ||
        old.interactiveSide != widget.interactiveSide ||
        old.lastMove != widget.lastMove) {
      _controller.updatePosition(_data());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Chessboard(
      size: widget.size,
      controller: _controller,
      orientation: widget.orientation,
      settings: GameBoard.settings,
      onMove: (move, {viaDragAndDrop}) => widget.onMove(move),
    );
  }
}
