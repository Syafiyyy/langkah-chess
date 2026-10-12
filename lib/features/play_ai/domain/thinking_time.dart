import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'bot_level.dart';

/// How long the bot should appear to think in [position] (search included),
/// so its moves don't come back instantly like a machine.
///
/// - Forced move (one legal move): 0.3–0.5 s.
/// - Levels 5–8: a short minimum, 0.6–1.2 s (their real search may be longer).
/// - Levels 1–4: 0.9–1.5 s base, scaled by how busy the position is (number
///   of legal moves, captures available, check), and quicker when it can take
///   back on the square [lastMove] landed on. Clamped to 0.6–2.5 s.
///
/// One draw from [random] per call, so the same seed gives the same "luck"
/// in different positions.
Duration naturalThinkTime(
  BotLevel level,
  Position position,
  Move? lastMove,
  Random random,
) {
  final luck = random.nextDouble();
  final moves = [
    for (final e in position.legalMoves.entries)
      for (final to in e.value.squares) (from: e.key, to: to),
  ];
  if (moves.length <= 1) return _ms(300 + luck * 200);
  if (level.style == null) return _ms(600 + luck * 600);

  final captures = moves.where((m) => position.board.pieceAt(m.to) != null);
  var ms = 900 + luck * 600;
  ms *= 0.75 + min(moves.length, 45) / 45 * 0.5;
  ms += min(captures.length, 8) * 60;
  if (position.isCheck) ms += 250;
  final landed = lastMove is NormalMove ? lastMove.to : null;
  if (landed != null && captures.any((m) => m.to == landed)) ms *= 0.55;
  return _ms(ms.clamp(600, 2500).toDouble());
}

/// Wait after a search that took [searched] so the move appears after
/// [target]. In a timed game the whole think (search + wait) stays within
/// [budget] (the clock's safe fraction), so the pause can never flag the bot.
Duration pauseAfterSearch({
  required Duration target,
  required Duration searched,
  required Duration? budget,
}) {
  var pause = target - searched;
  if (budget != null && searched + pause > budget) pause = budget - searched;
  return pause.isNegative ? Duration.zero : pause;
}

Duration _ms(double ms) => Duration(milliseconds: ms.round());
