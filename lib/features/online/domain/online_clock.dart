import 'package:dartchess/dartchess.dart';

import 'server_game.dart';

/// [side]'s time left at [serverNow]: the stored time, minus the time since
/// the last move for the side to move (ONLINE.md "Clocks"). Frozen before
/// both first moves and once the game is over.
Duration remainingTime(ServerGame game, Side side, DateTime serverNow) {
  final stored = Duration(milliseconds: game.storedMs(side));
  final since = game.lastMoveAt;
  if (!game.clocksRunning || side != game.turn || since == null) return stored;
  final left = stored - serverNow.difference(since);
  return left.isNegative ? Duration.zero : left;
}

/// Time left for the first move due now (plies 1 and 2 have a 30 s
/// deadline instead of a clock), or null when none is due.
Duration? firstMoveTimeLeft(ServerGame game, DateTime serverNow) {
  final deadline = game.firstMoveDeadline;
  if (!game.isActive || game.ply >= 2 || deadline == null) return null;
  final left = deadline.difference(serverNow);
  return left.isNegative ? Duration.zero : left;
}

/// How long until the side to move runs out (clock or first-move
/// deadline), or null when nothing can run out.
Duration? timeUntilFlag(ServerGame game, DateTime serverNow) {
  if (!game.isActive) return null;
  return firstMoveTimeLeft(game, serverNow) ??
      remainingTime(game, game.turn, serverNow);
}
