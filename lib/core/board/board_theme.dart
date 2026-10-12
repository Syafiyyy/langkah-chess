import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/painting.dart';

/// How the board's 6 px frame is drawn.
enum BoardFrameKind {
  /// Woven songket lattice: thin gold diagonals on navy.
  songket,

  /// A solid colour.
  solid,
}

/// A user-selectable board look (squares, highlights, frame).
///
/// chessground has one last-move highlight colour for both square colours,
/// so [colorScheme] uses a translucent overlay chosen to land close to
/// [lastMoveLight] on light squares and [lastMoveDark] on dark squares.
class BoardTheme {
  const BoardTheme._({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    required this.lastMoveLight,
    required this.lastMoveDark,
    required this.lastMoveOverlay,
    required this.frame,
    required this.frameColor,
  });

  final String id;
  final String name;
  final Color light;
  final Color dark;

  /// Target colours of a last-move square (design spec).
  final Color lastMoveLight;
  final Color lastMoveDark;

  /// Translucent overlay that approximates both targets (solved offline,
  /// see docs/STATE.md).
  final Color lastMoveOverlay;
  final BoardFrameKind frame;

  /// Frame colour (the lattice background for songket).
  final Color frameColor;

  static const songket = BoardTheme._(
    id: 'songket',
    name: 'Songket',
    light: Color(0xFFEFE3C8),
    dark: Color(0xFF3F6E73),
    lastMoveLight: Color(0xFFF2D688),
    lastMoveDark: Color(0xFF7FA06A),
    lastMoveOverlay: Color(0x70E3D34B),
    frame: BoardFrameKind.songket,
    frameColor: Color(0xFF18233A),
  );

  static const walnut = BoardTheme._(
    id: 'walnut',
    name: 'Walnut',
    light: Color(0xFFE9CFA6),
    dark: Color(0xFFA9774A),
    lastMoveLight: Color(0xFFF0D98C),
    lastMoveDark: Color(0xFFC79A4E),
    lastMoveOverlay: Color(0x54FFE757),
    frame: BoardFrameKind.solid,
    frameColor: Color(0xFF3A2A1E),
  );

  static const graphite = BoardTheme._(
    id: 'graphite',
    name: 'Graphite',
    light: Color(0xFFD8DEE6),
    dark: Color(0xFF6E7F92),
    lastMoveLight: Color(0xFFDDF0A0),
    lastMoveDark: Color(0xFF94AE5E),
    lastMoveOverlay: Color(0x57E2FF09),
    frame: BoardFrameKind.solid,
    frameColor: Color(0xFF1E242E),
  );

  static const List<BoardTheme> all = [songket, walnut, graphite];
  static const BoardTheme defaultTheme = songket;

  /// The theme with [id], or the default.
  static BoardTheme byId(String? id) =>
      all.where((t) => t.id == id).firstOrNull ?? defaultTheme;

  /// Frame width around the board.
  static const double frameWidth = 6;

  /// chessground colours for this theme (cached per theme).
  ChessboardColorScheme get colorScheme =>
      _schemes[id] ??= ChessboardColorScheme(
        lightSquare: light,
        darkSquare: dark,
        background: SolidColorChessboardBackground(
          lightSquare: light,
          darkSquare: dark,
        ),
        whiteCoordBackground: SolidColorChessboardBackground(
          lightSquare: light,
          darkSquare: dark,
          coordinates: true,
        ),
        blackCoordBackground: SolidColorChessboardBackground(
          lightSquare: light,
          darkSquare: dark,
          coordinates: true,
          orientation: Side.black,
        ),
        lastMove: HighlightDetails(solidColor: lastMoveOverlay),
        selected: const HighlightDetails(solidColor: Color(0x80D9A93F)),
        validMoves: const Color(0x55101826),
        validPremoves: const Color(0x40203085),
      );

  static final Map<String, ChessboardColorScheme> _schemes = {};
}
