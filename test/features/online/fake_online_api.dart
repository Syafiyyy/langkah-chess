import 'package:dartchess/dartchess.dart';
import 'package:skak/features/online/data/online_api.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

/// In-memory server for online tests. Plays moves with dartchess, records
/// every call, and fails on demand.
class FakeOnlineApi implements OnlineApi {
  FakeOnlineApi({this.userId = 'me'});

  @override
  final String userId;

  final games = <String, ServerGame>{};
  final moves = <String, List<ServerMove>>{};
  final calls = <String>[];
  final moveIds = <String>{};
  DateTime now = DateTime.utc(2026, 10, 16, 12);

  /// Failures thrown by the next calls of a kind (`makeMove`, `fetch`,
  /// `rpc`), first in first out.
  final failures = <String, List<OnlineFailure>>{};

  /// When true, a failing makeMove still applies the move first (the
  /// response got lost on the way back).
  bool applyThenFail = false;

  ServerGame? queuedGame;
  Map<String, PlayerInfo> profiles = {
    'me': const PlayerInfo(username: 'me_user', rating: 1200),
    'opp': const PlayerInfo(username: 'opponent', rating: 1300),
  };
  int? rating = 12;

  final _gameWatchers = <String, List<_Watcher>>{};
  final _myWatchers = <void Function()>[];

  void _fail(String kind) {
    final list = failures[kind];
    if (list == null || list.isEmpty) return;
    // Copy: tests may pass fixed-length lists.
    failures[kind] = list.sublist(1);
    throw list.first;
  }

  /// A game between me and opp; [mySide] decides colours.
  ServerGame addGame({
    String id = 'g1',
    Side mySide = Side.white,
    GameStatus status = GameStatus.active,
    int baseMs = 300000,
    int incMs = 0,
  }) {
    final g = ServerGame(
      id: id,
      status: status,
      mode: 'invite',
      timeBaseMs: baseMs,
      incrementMs: incMs,
      fen: Chess.initial.fen,
      ply: 0,
      whiteMs: baseMs,
      blackMs: baseMs,
      whiteId: mySide == Side.white ? 'me' : 'opp',
      blackId: mySide == Side.white ? 'opp' : 'me',
      createdBy: 'me',
      lastMoveAt: now,
      firstMoveDeadline: now.add(const Duration(seconds: 30)),
      inviteCode: 'ABC234',
      createdAt: now,
    );
    games[id] = g;
    moves[id] = [];
    return g;
  }

  /// Applies [uci] on the server (as either player) without a request.
  void serverMove(String gameId, String uci) {
    final g = games[gameId]!;
    final pos = Chess.fromSetup(Setup.parseFen(g.fen));
    final move = Move.parse(uci)!;
    final (after, san) = pos.makeSan(move);
    final ply = g.ply + 1;
    moves[gameId]!.add(
      ServerMove(ply: ply, uci: uci, san: san, fenAfter: after.fen),
    );
    var next = copy(g, fen: after.fen, ply: ply, lastMoveAt: now);
    if (after.isCheckmate) {
      next = copy(
        next,
        status: GameStatus.finished,
        result: after.turn == Side.white ? 'black' : 'white',
        termination: 'checkmate',
      );
    }
    games[gameId] = next;
  }

  /// Replaces fields of [g].
  ServerGame copy(
    ServerGame g, {
    GameStatus? status,
    String? fen,
    int? ply,
    int? whiteMs,
    int? blackMs,
    DateTime? lastMoveAt,
    String? result,
    String? termination,
    String? drawOfferBy,
    bool clearDrawOffer = false,
    String? rematchCode,
    String? rematchBy,
  }) => ServerGame(
    id: g.id,
    status: status ?? g.status,
    mode: g.mode,
    timeBaseMs: g.timeBaseMs,
    incrementMs: g.incrementMs,
    fen: fen ?? g.fen,
    ply: ply ?? g.ply,
    whiteMs: whiteMs ?? g.whiteMs,
    blackMs: blackMs ?? g.blackMs,
    whiteId: g.whiteId,
    blackId: g.blackId,
    createdBy: g.createdBy,
    lastMoveAt: lastMoveAt ?? g.lastMoveAt,
    firstMoveDeadline: g.firstMoveDeadline,
    result: result ?? g.result,
    termination: termination ?? g.termination,
    inviteCode: g.inviteCode,
    drawOfferBy: clearDrawOffer ? null : drawOfferBy ?? g.drawOfferBy,
    rematchCode: rematchCode ?? g.rematchCode,
    rematchBy: rematchBy ?? g.rematchBy,
    createdAt: g.createdAt,
    finishedAt: g.finishedAt,
  );

  void setGame(ServerGame g) => games[g.id] = g;

  /// Fires the Realtime hint for [gameId].
  void hint(String gameId) {
    for (final w in [...?_gameWatchers[gameId]]) {
      w.onHint();
    }
  }

  void setConnected(String gameId, bool up) {
    for (final w in [...?_gameWatchers[gameId]]) {
      w.onConnected(up);
    }
  }

  void hintMine() {
    for (final w in [..._myWatchers]) {
      w();
    }
  }

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  @override
  Future<ServerGame> createInvite(TimeControl tc) async {
    calls.add('createInvite ${tc.label}');
    _fail('rpc');
    return games['inv'] ??= ServerGame(
      id: 'inv',
      status: GameStatus.waiting,
      mode: 'invite',
      timeBaseMs: tc.initial.inMilliseconds,
      incrementMs: tc.increment.inMilliseconds,
      fen: Chess.initial.fen,
      ply: 0,
      whiteMs: tc.initial.inMilliseconds,
      blackMs: tc.initial.inMilliseconds,
      createdBy: userId,
      inviteCode: 'RVMP92',
    );
  }

  @override
  Future<ServerGame> joinInvite(String code) async {
    calls.add('joinInvite $code');
    _fail('rpc');
    return games.values.firstWhere(
      (g) => g.inviteCode == code,
      orElse: () => throw const OnlineRejected('NOT_FOUND'),
    );
  }

  @override
  Future<ServerGame?> joinQueue(TimeControl tc) async {
    calls.add('joinQueue ${tc.label}');
    _fail('rpc');
    return queuedGame;
  }

  @override
  Future<void> leaveQueue() async {
    calls.add('leaveQueue');
  }

  @override
  Future<ServerGame> fetchGame(String gameId) async {
    calls.add('fetchGame');
    _fail('fetch');
    return games[gameId] ?? (throw const OnlineRejected('NOT_FOUND'));
  }

  @override
  Future<List<ServerMove>> fetchMoves(String gameId, {int afterPly = 0}) async {
    calls.add('fetchMoves $afterPly');
    _fail('fetch');
    return moves[gameId]!.where((m) => m.ply > afterPly).toList();
  }

  @override
  Future<MoveResponse> makeMove({
    required String gameId,
    required int ply,
    required String uci,
    required String clientMoveId,
  }) async {
    calls.add('makeMove $ply $uci $clientMoveId');
    final list = failures['makeMove'];
    final failing = list != null && list.isNotEmpty;
    if (failing && !applyThenFail) _fail('makeMove');
    if (moveIds.contains(clientMoveId)) {
      if (failing) _fail('makeMove');
      return MoveResponse(game: games[gameId]!, applied: true, serverNow: now);
    }
    final g = games[gameId]!;
    if (!g.isActive) throw const OnlineRejected('GAME_OVER');
    if (ply != g.ply + 1) throw const OnlineRejected('STALE');
    moveIds.add(clientMoveId);
    serverMove(gameId, uci);
    if (failing) _fail('makeMove');
    return MoveResponse(game: games[gameId]!, applied: true, serverNow: now);
  }

  @override
  Future<ServerGame> act(GameAction action, String gameId) async {
    calls.add('act ${action.name}');
    _fail('rpc');
    final g = games[gameId]!;
    final winner = g.whiteId == userId ? 'black' : 'white';
    final next = switch (action) {
      GameAction.resign => copy(
        g,
        status: GameStatus.finished,
        result: winner,
        termination: 'resignation',
      ),
      GameAction.offerDraw => copy(g, drawOfferBy: userId),
      GameAction.acceptDraw => copy(
        g,
        status: GameStatus.finished,
        result: 'draw',
        termination: 'agreement',
      ),
      GameAction.declineDraw => copy(g, clearDrawOffer: true),
      GameAction.abort => copy(
        g,
        status: GameStatus.aborted,
        termination: 'aborted',
      ),
      GameAction.claimTimeout => g,
    };
    games[gameId] = next;
    return next;
  }

  @override
  Future<ServerGame> offerRematch(String gameId) async {
    calls.add('offerRematch');
    _fail('rpc');
    final g = games[gameId]!;
    games[gameId] = copy(g, rematchCode: 'NEW234', rematchBy: userId);
    return addGame(id: 'rematch', status: GameStatus.waiting);
  }

  @override
  Future<Map<String, PlayerInfo>> players(Iterable<String> ids) async {
    calls.add('players');
    return {for (final id in ids) id: ?profiles[id]};
  }

  @override
  Future<int?> ratingChange(String gameId) async {
    calls.add('ratingChange');
    return rating;
  }

  @override
  Future<ServerGame?> activeGame() async =>
      games.values.where((g) => g.isActive).firstOrNull;

  @override
  Future<List<ServerGame>> finishedGames({int limit = 50}) async {
    calls.add('finishedGames');
    return games.values.where((g) => g.status == GameStatus.finished).toList();
  }

  @override
  Subscription watchGame(
    String gameId, {
    required void Function() onHint,
    required void Function(bool connected) onConnected,
  }) {
    calls.add('watchGame');
    final w = _Watcher(onHint, onConnected);
    (_gameWatchers[gameId] ??= []).add(w);
    return _Sub(() => _gameWatchers[gameId]!.remove(w));
  }

  int watchers(String gameId) => _gameWatchers[gameId]?.length ?? 0;

  @override
  Subscription watchMyGames({required void Function() onHint}) {
    calls.add('watchMyGames');
    _myWatchers.add(onHint);
    return _Sub(() => _myWatchers.remove(onHint));
  }
}

class _Watcher {
  _Watcher(this.onHint, this.onConnected);

  final void Function() onHint;
  final void Function(bool) onConnected;
}

class _Sub implements Subscription {
  _Sub(this._cancel);

  final void Function() _cancel;

  @override
  void cancel() => _cancel();
}
