import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/board/board_prefs.dart';
import 'board_frame.dart';

/// A non-interactive board in the player's theme and piece set, framed.
/// [size] is the board size without the frame.
class ThemedBoard extends ConsumerWidget {
  const ThemedBoard({
    super.key,
    required this.size,
    required this.orientation,
    required this.fen,
    this.lastMove,
    this.shapes = const {},
  });

  final double size;
  final Side orientation;
  final String fen;
  final Move? lastMove;
  final Set<Shape> shapes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(boardPrefsProvider);
    return BoardFrame(
      theme: prefs.theme,
      boardSize: size,
      child: StaticChessboard(
        size: size,
        orientation: orientation,
        fen: fen,
        lastMove: lastMove,
        shapes: shapes,
        settings: StaticChessboardSettings(
          colorScheme: prefs.theme.colorScheme,
          pieceAssets: prefs.pieces.assets,
          enableCoordinates: true,
        ),
      ),
    );
  }
}
