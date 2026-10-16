import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/game_result.dart';
import 'server_game.dart';

/// The result of a finished server game in the app's result types, or null
/// while it runs or when it was aborted (aborted games have no result).
GameResult? serverResult(ServerGame game) {
  if (game.status != GameStatus.finished) return null;
  final outcome = switch (game.result) {
    'white' => Outcome.whiteWins,
    'black' => Outcome.blackWins,
    _ => Outcome.draw,
  };
  final termination = Termination.values.asNameMap()[game.termination];
  if (termination == null) return null;
  return GameResult(outcome, termination);
}

/// Why an aborted game ended (it is unrated).
String abortReason(ServerGame game) => switch (game.termination) {
  'firstMoveTimeout' => 'No first move in time',
  'expired' => 'Nobody joined within 24 hours',
  _ => 'Game aborted',
};
