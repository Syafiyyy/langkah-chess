import '../data/online_api.dart';
import '../domain/server_game.dart';

/// The server's game and a consistent move list (one move per ply): only the
/// moves after the [known] ones are fetched, unless they don't chain on (the
/// server rolled back, or a gap), then all of them.
Future<(ServerGame, List<ServerMove>)> fetchSnapshot(
  OnlineApi api,
  String gameId,
  List<ServerMove> known,
) async {
  final game = await api.fetchGame(gameId);
  var moves = known;
  if (game.ply > known.length) {
    final more = await api.fetchMoves(gameId, afterPly: known.length);
    moves = _chains(more, known.length, game.ply)
        ? [...known, ...more]
        : await api.fetchMoves(gameId);
  } else if (game.ply < known.length) {
    moves = await api.fetchMoves(gameId);
  }
  if (moves.length != game.ply) moves = await api.fetchMoves(gameId);
  return (game, moves);
}

bool _chains(List<ServerMove> more, int known, int ply) {
  if (more.length != ply - known) return false;
  for (var i = 0; i < more.length; i++) {
    if (more[i].ply != known + i + 1) return false;
  }
  return true;
}

/// Short, non-blaming text for a move the server did not take.
String rejectedMoveNotice(String code) => switch (code) {
  'GAME_OVER' => 'The game had already ended.',
  'STALE' || 'NOT_YOUR_TURN' => 'The game moved on. The board is back in sync.',
  _ => lostMoveNotice,
};

const String lostMoveNotice =
    "That move didn't go through. The board is back in sync.";
