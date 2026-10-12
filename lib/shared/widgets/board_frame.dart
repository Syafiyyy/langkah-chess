import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/board/board_theme.dart';

/// The board theme's 6 px frame around a board of [boardSize].
/// Total size is `boardSize + 2 * BoardTheme.frameWidth`.
class BoardFrame extends StatelessWidget {
  const BoardFrame({
    super.key,
    required this.theme,
    required this.boardSize,
    required this.child,
  });

  final BoardTheme theme;
  final double boardSize;
  final Widget child;

  /// Board size that fits in [available] once the frame is added.
  static double boardSizeFor(double available) =>
      (available - 2 * BoardTheme.frameWidth).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    const w = BoardTheme.frameWidth;
    final outer = boardSize + 2 * w;
    return SizedBox.square(
      dimension: outer,
      child: CustomPaint(
        painter: theme.frame == BoardFrameKind.songket
            ? _SongketFramePainter(theme.frameColor)
            : _SolidFramePainter(theme.frameColor),
        child: Padding(padding: const EdgeInsets.all(w), child: child),
      ),
    );
  }
}

class _SolidFramePainter extends CustomPainter {
  const _SolidFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SolidFramePainter old) => old.color != color;
}

/// Woven songket lattice: thin gold diagonals both ways on navy.
class _SongketFramePainter extends CustomPainter {
  const _SongketFramePainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    final inner = rect.deflate(BoardTheme.frameWidth);
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect)
          ..addRect(inner),
      );
    final line = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    const step = 6.0;
    final span = size.width + size.height;
    for (var d = -size.height; d < span; d += step) {
      canvas
        ..drawLine(Offset(d, 0), Offset(d + size.height, size.height), line)
        ..drawLine(Offset(d + size.height, 0), Offset(d, size.height), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SongketFramePainter old) => old.background != background;
}
