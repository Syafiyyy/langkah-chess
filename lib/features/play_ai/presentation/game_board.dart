import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_motion.dart';
import '../../../core/board/board_prefs.dart';
import '../../../shared/widgets/board_frame.dart';

/// Interactive chessground board driven by a dartchess position, in the
/// player's board theme and piece set, inside the theme's frame.
///
/// The board only renders [position]; moves go out through [onMove] and come
/// back as a new [position]. Premoves are off. Promotion uses chessground's
/// own piece picker.
class GameBoard extends ConsumerStatefulWidget {
  const GameBoard({
    super.key,
    required this.size,
    required this.position,
    required this.lastMove,
    required this.orientation,
    required this.interactiveSide,
    required this.onMove,
  });

  /// Board size without the frame.
  final double size;
  final Position position;
  final Move? lastMove;
  final Side orientation;

  /// The side that may move now, or null when the board is locked.
  final Side? interactiveSide;
  final void Function(Move move) onMove;

  @override
  ConsumerState<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends ConsumerState<GameBoard> {
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
    final prefs = ref.watch(boardPrefsProvider);
    return BoardFrame(
      theme: prefs.theme,
      boardSize: widget.size,
      child: Chessboard(
        size: widget.size,
        controller: _controller,
        orientation: widget.orientation,
        settings: ChessboardSettings(
          colorScheme: prefs.theme.colorScheme,
          pieceAssets: prefs.pieces.assets,
          enablePremoves: false,
          enablePremoveCastling: false,
          animationDuration: AppMotion.of(context, AppMotion.base),
        ),
        onMove: (move, {viaDragAndDrop}) => widget.onMove(move),
      ),
    );
  }
}
