import 'package:dartchess/dartchess.dart';

import '../../play_ai/domain/time_control.dart';

enum GameStatus { waiting, active, finished, aborted }

/// A `games` row as the server sent it. The server's state always wins.
class ServerGame {
  const ServerGame({
    required this.id,
    required this.status,
    required this.mode,
    required this.timeBaseMs,
    required this.incrementMs,
    required this.fen,
    required this.ply,
    required this.whiteMs,
    required this.blackMs,
    this.whiteId,
    this.blackId,
    this.createdBy,
    this.lastMoveAt,
    this.firstMoveDeadline,
    this.result,
    this.termination,
    this.inviteCode,
    this.drawOfferBy,
    this.rematchCode,
    this.rematchBy,
    this.createdAt,
    this.finishedAt,
  });

  factory ServerGame.fromRow(Map<String, dynamic> r) => ServerGame(
    id: r['id'] as String,
    status: GameStatus.values.byName(r['status'] as String),
    mode: r['mode'] as String,
    timeBaseMs: r['time_base_ms'] as int,
    incrementMs: r['increment_ms'] as int,
    fen: r['fen'] as String,
    ply: r['ply'] as int,
    whiteMs: r['white_ms'] as int,
    blackMs: r['black_ms'] as int,
    whiteId: r['white_id'] as String?,
    blackId: r['black_id'] as String?,
    createdBy: r['created_by'] as String?,
    lastMoveAt: _time(r['last_move_at']),
    firstMoveDeadline: _time(r['first_move_deadline']),
    result: r['result'] as String?,
    termination: r['termination'] as String?,
    inviteCode: r['invite_code'] as String?,
    drawOfferBy: r['draw_offer_by'] as String?,
    rematchCode: r['rematch_code'] as String?,
    rematchBy: r['rematch_by'] as String?,
    createdAt: _time(r['created_at']),
    finishedAt: _time(r['finished_at']),
  );

  static DateTime? _time(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toUtc();

  final String id;
  final GameStatus status;

  /// `invite` or `matchmaking`.
  final String mode;
  final int timeBaseMs;
  final int incrementMs;
  final String fen;

  /// Moves made so far; even = White to move.
  final int ply;

  /// Time left as of [lastMoveAt].
  final int whiteMs;
  final int blackMs;
  final String? whiteId;
  final String? blackId;
  final String? createdBy;
  final DateTime? lastMoveAt;
  final DateTime? firstMoveDeadline;

  /// `white`, `black`, `draw`, or null (running or aborted).
  final String? result;
  final String? termination;
  final String? inviteCode;
  final String? drawOfferBy;

  /// Set on a finished game when a player offered a rematch: the code of
  /// the new invite and who made it.
  final String? rematchCode;
  final String? rematchBy;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  bool get isActive => status == GameStatus.active;
  bool get isOver =>
      status == GameStatus.finished || status == GameStatus.aborted;

  Side get turn => ply.isEven ? Side.white : Side.black;

  /// Clocks run only after both first moves.
  bool get clocksRunning => isActive && ply >= 2;

  TimeControl get timeControl =>
      TimeControl.minutes(timeBaseMs ~/ 60000, incrementMs ~/ 1000);

  /// The side [userId] plays, or null.
  Side? sideOf(String userId) => userId == whiteId
      ? Side.white
      : userId == blackId
      ? Side.black
      : null;

  String? playerId(Side side) => side == Side.white ? whiteId : blackId;

  int storedMs(Side side) => side == Side.white ? whiteMs : blackMs;
}

/// A `moves` row.
class ServerMove {
  const ServerMove({
    required this.ply,
    required this.uci,
    required this.san,
    required this.fenAfter,
  });

  factory ServerMove.fromRow(Map<String, dynamic> r) => ServerMove(
    ply: r['ply'] as int,
    uci: r['uci'] as String,
    san: r['san'] as String,
    fenAfter: r['fen_after'] as String,
  );

  final int ply;
  final String uci;
  final String san;
  final String fenAfter;
}

/// A player's public name and rating.
class PlayerInfo {
  const PlayerInfo({required this.username, required this.rating});

  /// For a player whose account was deleted (their id is null).
  static const PlayerInfo deleted = PlayerInfo(
    username: 'Deleted player',
    rating: null,
  );

  final String username;
  final int? rating;
}
