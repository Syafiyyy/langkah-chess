import '../../play_ai/domain/time_control.dart';
import '../domain/server_game.dart';

/// Everything the app asks the server about online games (ONLINE.md). The
/// app never writes tables: moves go through `make_move`, the rest through
/// RPCs. Failures are [OnlineFailure]s.
abstract interface class OnlineApi {
  String get userId;

  Future<ServerGame> createInvite(TimeControl tc);
  Future<ServerGame> joinInvite(String code);

  /// The game once paired, or null while queued. Also the queue heartbeat.
  Future<ServerGame?> joinQueue(TimeControl tc);
  Future<void> leaveQueue();

  Future<ServerGame> fetchGame(String gameId);

  /// Moves with `ply > afterPly`, in order.
  Future<List<ServerMove>> fetchMoves(String gameId, {int afterPly = 0});

  /// Plays a move. Retrying with the same [clientMoveId] is always safe.
  Future<MoveResponse> makeMove({
    required String gameId,
    required int ply,
    required String uci,
    required String clientMoveId,
  });

  Future<ServerGame> act(GameAction action, String gameId);

  /// Offers a rematch, or accepts the opponent's offer. Returns the new game
  /// (waiting for the opponent, or active when both offered).
  Future<ServerGame> offerRematch(String gameId);

  Future<Map<String, PlayerInfo>> players(Iterable<String> ids);

  /// The signed-in player's rating change in a finished game, if rated.
  Future<int?> ratingChange(String gameId);

  /// The signed-in player's running game, if any (newest).
  Future<ServerGame?> activeGame();

  /// The signed-in player's finished games, newest first.
  Future<List<ServerGame>> finishedGames({int limit = 50});

  /// Realtime hints for one game: [onHint] on any change, [onConnected]
  /// with true when (re)subscribed and false when the channel drops.
  Subscription watchGame(
    String gameId, {
    required void Function() onHint,
    required void Function(bool connected) onConnected,
  });

  /// Hints when a game where the player is White or Black changes (used
  /// while queued to learn about a pairing).
  Subscription watchMyGames({required void Function() onHint});
}

enum GameAction {
  resign,
  offerDraw,
  acceptDraw,
  declineDraw,
  abort,
  claimTimeout,
}

abstract interface class Subscription {
  void cancel();
}

class MoveResponse {
  const MoveResponse({
    required this.game,
    required this.applied,
    required this.serverNow,
  });

  final ServerGame game;

  /// False: the mover's clock had run out; the game ended on time.
  final bool applied;
  final DateTime? serverNow;
}

sealed class OnlineFailure implements Exception {
  const OnlineFailure();
}

/// No answer (no network, timeout, server error): retry or resync later.
class OnlineUnavailable extends OnlineFailure {
  const OnlineUnavailable([this.cause]);

  final Object? cause;

  @override
  String toString() => 'OnlineUnavailable($cause)';
}

/// The server said no; [code] is the error code (`STALE`, `NOT_FOUND`, …).
class OnlineRejected extends OnlineFailure {
  const OnlineRejected(this.code);

  final String code;

  @override
  String toString() => 'OnlineRejected($code)';
}
