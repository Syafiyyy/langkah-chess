import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/game_result.dart';
import '../domain/online_result.dart';
import '../domain/server_game.dart';

/// A move shown on the board before the server confirmed it.
class PendingMove {
  const PendingMove({
    required this.ply,
    required this.uci,
    required this.san,
    required this.clientMoveId,
    required this.madeAt,
  });

  final int ply;
  final String uci;
  final String san;

  /// Generated once per attempt and reused on every retry.
  final String clientMoveId;

  /// Server time when it was played (the mover's clock stops there).
  final DateTime madeAt;
}

/// Everything the online game screen shows. The server's [game] and
/// [moves] are the truth; [pending] is the player's optimistic move.
class OnlineGameView {
  OnlineGameView({
    required this.game,
    required this.moves,
    required this.mySide,
    required this.players,
    this.pending,
    this.connected = false,
    this.requestFailing = false,
    this.notice,
    this.ratingChange,
    this.viewedPly,
  });

  final ServerGame game;

  /// Confirmed moves, plies 1..n.
  final List<ServerMove> moves;
  final Side mySide;

  /// Usernames and ratings by user id.
  final Map<String, PlayerInfo> players;
  final PendingMove? pending;

  /// The Realtime channel is subscribed.
  final bool connected;

  /// The last request failed for lack of an answer.
  final bool requestFailing;

  /// A short message after a rejected move or action.
  final String? notice;
  final int? ratingChange;

  /// Browsing an earlier position (null = live).
  final int? viewedPly;

  late final List<Position> positions = _replay();
  late final List<String> sans = [
    for (final m in moves) m.san,
    if (pending case final p?) p.san,
  ];

  List<Position> _replay() {
    final out = <Position>[Chess.initial];
    final ucis = [for (final m in moves) m.uci, ?pending?.uci];
    for (final uci in ucis) {
      final move = Move.parse(uci);
      if (move == null || !out.last.isLegal(move)) break;
      out.add(out.last.play(move));
    }
    return out;
  }

  Position get position => positions.last;

  /// Banner: the channel is down or requests are failing.
  bool get reconnecting => !connected || requestFailing;

  bool get isBrowsing => viewedPly != null;

  GameResult? get result => serverResult(game);

  bool get isMyTurn =>
      game.isActive && pending == null && position.turn == mySide;

  /// Abort is possible until both players have moved.
  bool get canAbort => game.isActive && game.ply < 2;

  bool get opponentOffersDraw =>
      game.isActive && game.drawOfferBy != null && game.drawOfferBy != myId;

  bool get iOfferDraw => game.isActive && game.drawOfferBy == myId;

  String? get myId => game.playerId(mySide);

  PlayerInfo player(Side side) {
    final id = game.playerId(side);
    return id == null
        ? PlayerInfo.deleted
        : players[id] ?? const PlayerInfo(username: '…', rating: null);
  }

  /// The opponent offered a rematch (code of their new invite).
  bool get opponentOffersRematch =>
      game.rematchCode != null && game.rematchBy != myId;

  bool get iOfferedRematch =>
      game.rematchCode != null && game.rematchBy == myId;

  OnlineGameView copyWith({
    ServerGame? game,
    List<ServerMove>? moves,
    Map<String, PlayerInfo>? players,
    PendingMove? pending,
    bool clearPending = false,
    bool? connected,
    bool? requestFailing,
    String? notice,
    bool clearNotice = false,
    int? ratingChange,
    int? viewedPly,
    bool clearViewedPly = false,
  }) => OnlineGameView(
    game: game ?? this.game,
    moves: moves ?? this.moves,
    mySide: mySide,
    players: players ?? this.players,
    pending: clearPending ? null : pending ?? this.pending,
    connected: connected ?? this.connected,
    requestFailing: requestFailing ?? this.requestFailing,
    notice: clearNotice ? null : notice ?? this.notice,
    ratingChange: ratingChange ?? this.ratingChange,
    viewedPly: clearViewedPly ? null : viewedPly ?? this.viewedPly,
  );
}
