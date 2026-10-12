import 'package:chessground/chessground.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/board/board_theme.dart';
import 'package:langkah/core/board/piece_choice.dart';

void main() {
  test('three themes with the approved square colours, songket first', () {
    expect(BoardTheme.all.map((t) => t.id), ['songket', 'walnut', 'graphite']);
    expect(BoardTheme.defaultTheme.id, 'songket');
    final s = BoardTheme.songket.colorScheme;
    expect(s.lightSquare, const Color(0xFFEFE3C8));
    expect(s.darkSquare, const Color(0xFF3F6E73));
    expect(BoardTheme.walnut.colorScheme.darkSquare, const Color(0xFFA9774A));
    expect(
      BoardTheme.graphite.colorScheme.lightSquare,
      const Color(0xFFD8DEE6),
    );
  });

  test('backgrounds use the same squares, with and without coordinates', () {
    for (final theme in BoardTheme.all) {
      final s = theme.colorScheme;
      for (final bg in [
        s.background,
        s.whiteCoordBackground,
        s.blackCoordBackground,
      ]) {
        expect(bg.lightSquare, s.lightSquare, reason: theme.id);
        expect(bg.darkSquare, s.darkSquare, reason: theme.id);
      }
      expect(s.whiteCoordBackground.coordinates, isTrue);
      expect(s.background.coordinates, isFalse);
    }
  });

  test('the last-move overlay lands near both target colours', () {
    // Blending one translucent colour over light and dark squares.
    Color blend(Color over, Color base) => Color.alphaBlend(over, base);
    int distance(Color a, Color b) => [
      (a.r - b.r).abs(),
      (a.g - b.g).abs(),
      (a.b - b.b).abs(),
    ].map((d) => (d * 255).round()).reduce((x, y) => x > y ? x : y);

    for (final theme in BoardTheme.all) {
      final s = theme.colorScheme;
      final overlay = s.lastMove.solidColor!;
      expect(
        distance(blend(overlay, s.lightSquare), theme.lastMoveLight),
        lessThanOrEqualTo(16),
        reason: '${theme.id} light',
      );
      expect(
        distance(blend(overlay, s.darkSquare), theme.lastMoveDark),
        lessThanOrEqualTo(16),
        reason: '${theme.id} dark',
      );
    }
  });

  test('byId falls back to the default theme', () {
    expect(BoardTheme.byId('walnut'), BoardTheme.walnut);
    expect(BoardTheme.byId('nope'), BoardTheme.songket);
    expect(BoardTheme.byId(null), BoardTheme.songket);
  });

  test('piece sets: four bundled chessground sets, cburnett default', () {
    expect(PieceChoice.values.map((p) => p.pieceSet), [
      PieceSet.cburnett,
      PieceSet.merida,
      PieceSet.california,
      PieceSet.staunty,
    ]);
    expect(PieceChoice.defaultChoice, PieceChoice.cburnett);
    expect(PieceChoice.byName('staunty'), PieceChoice.staunty);
    expect(PieceChoice.byName('nope'), PieceChoice.cburnett);
  });
}
