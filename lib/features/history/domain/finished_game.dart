import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/game_pgn.dart';
import '../../play_ai/domain/game_result.dart';
import '../../play_ai/domain/game_state.dart';
import '../../play_ai/domain/time_control.dart';

/// The game's result from the player's point of view.
enum PlayerResult { win, loss, draw }

/// Which games the history list shows.
enum HistoryFilter { all, wins, losses, draws }

/// A finished game as stored in local history: against the bot, or online
/// (then [opponent] is set and [botLevel] is 0).
class FinishedGame {
  const FinishedGame({
    required this.id,
    required this.endedAt,
    required this.playerSide,
    required this.botLevel,
    required this.timeControl,
    required this.result,
    required this.pgn,
    required this.finalFen,
    required this.plies,
    required this.duration,
    this.opponent,
    this.ratingChange,
  });

  /// Snapshot of a finished [state].
  factory FinishedGame.fromState(GameState state) => FinishedGame(
    id: state.id,
    endedAt: state.endedAt!,
    playerSide: state.playerSide,
    botLevel: state.level.number,
    timeControl: state.timeControl,
    result: state.result!,
    pgn: gamePgn(state),
    finalFen: state.position.fen,
    plies: state.moves.length,
    duration: state.endedAt!.difference(state.startedAt),
  );

  final String id;
  final DateTime endedAt;
  final Side playerSide;
  final int botLevel;
  final TimeControl timeControl;
  final GameResult result;

  /// Full PGN with headers.
  final String pgn;
  final String finalFen;

  /// Half-moves played.
  final int plies;

  /// Wall-clock time from start to end.
  final Duration duration;

  /// Online opponent's username; null for games against the bot.
  final String? opponent;

  /// The player's rating change (online, rated games only).
  final int? ratingChange;

  bool get isOnline => opponent != null;

  /// "vs gate_b" online, "Level 3" against the bot.
  String get opponentLabel => isOnline ? 'vs $opponent' : 'Level $botLevel';

  /// Full moves, as shown to players (41 plies = 21 moves).
  int get moveCount => (plies + 1) ~/ 2;

  PlayerResult get playerResult {
    final winner = result.outcome.winner;
    if (winner == null) return PlayerResult.draw;
    return winner == playerSide ? PlayerResult.win : PlayerResult.loss;
  }
}
