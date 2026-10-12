import 'package:dartchess/dartchess.dart';

import '../../../core/chess/win_percent.dart';

/// The engine's verdict on one position, always from White's point of view.
///
/// UCI scores are from the side to move; [PositionEval.fromSideToMove] is the
/// one place they are flipped. Finished positions (mate, stalemate, ...) are
/// not sent to the engine and carry their [result] instead.
class PositionEval {
  const PositionEval({
    this.cp,
    this.mate,
    this.bestMove,
    this.pv = const [],
    this.result,
  });

  /// Converts an engine score for the side to move ([turn]) to White's view.
  factory PositionEval.fromSideToMove({
    required Side turn,
    int? cp,
    int? mate,
    String? bestMove,
    List<String> pv = const [],
  }) {
    final sign = turn == Side.white ? 1 : -1;
    return PositionEval(
      cp: cp == null ? null : cp * sign,
      mate: mate == null ? null : mate * sign,
      bestMove: bestMove,
      pv: pv,
    );
  }

  /// A position where the game is over.
  factory PositionEval.gameOver(Outcome result) => PositionEval(result: result);

  factory PositionEval.fromJson(Map<String, Object?> json) => PositionEval(
    cp: json['cp'] as int?,
    mate: json['mate'] as int?,
    bestMove: json['best'] as String?,
    pv: (json['pv'] as List<Object?>?)?.cast<String>() ?? const [],
    result: Outcome.fromPgn(json['result'] as String?),
  );

  /// Centipawns, White's view. Null for mate scores and finished games.
  final int? cp;

  /// Moves to mate, White's view (> 0: White mates).
  final int? mate;

  /// Engine's best move here (UCI), if the game is not over.
  final String? bestMove;
  final List<String> pv;

  /// Set only for finished positions.
  final Outcome? result;

  /// White's winning chance, 0..100.
  double get whiteWin {
    final r = result;
    if (r != null) {
      return switch (r.winner) {
        Side.white => 100,
        Side.black => 0,
        null => 50,
      };
    }
    return winPercent(cp: cp, mate: mate);
  }

  /// Winning chance for [side], 0..100.
  double winFor(Side side) => side == Side.white ? whiteWin : 100 - whiteWin;

  Map<String, Object?> toJson() => {
    if (cp != null) 'cp': cp,
    if (mate != null) 'mate': mate,
    if (bestMove != null) 'best': bestMove,
    if (pv.isNotEmpty) 'pv': pv,
    if (result != null) 'result': Outcome.toPgnString(result),
  };
}
