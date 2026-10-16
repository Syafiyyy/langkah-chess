import 'package:dartchess/dartchess.dart';
import 'package:sqflite/sqflite.dart';

import '../../play_ai/domain/game_result.dart';
import '../../play_ai/domain/time_control.dart';
import '../domain/finished_game.dart';

export '../domain/finished_game.dart' show HistoryFilter;

/// Local store of finished games (bot and online).
abstract interface class HistoryRepository {
  /// Saves [game]. Saving the same id again is a no-op.
  Future<void> save(FinishedGame game);

  /// Games matching [filter], newest first.
  Future<List<FinishedGame>> list({HistoryFilter filter = HistoryFilter.all});

  Future<FinishedGame?> byId(String id);
}

/// sqflite implementation on the app database's `games` table.
class SqfliteHistoryRepository implements HistoryRepository {
  SqfliteHistoryRepository(this._db);

  final Database _db;

  @override
  Future<void> save(FinishedGame game) async {
    // async so a synchronous sqflite throw becomes a failed Future.
    await _db.insert(
      'games',
      _toRow(game),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<FinishedGame>> list({
    HistoryFilter filter = HistoryFilter.all,
  }) async {
    final result = switch (filter) {
      HistoryFilter.all => null,
      HistoryFilter.wins => PlayerResult.win,
      HistoryFilter.losses => PlayerResult.loss,
      HistoryFilter.draws => PlayerResult.draw,
    };
    final rows = await _db.query(
      'games',
      where: result == null ? null : 'player_result = ?',
      whereArgs: result == null ? null : [result.name],
      orderBy: 'ended_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<FinishedGame?> byId(String id) async {
    final rows = await _db.query('games', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  static Map<String, Object?> _toRow(FinishedGame g) => {
    'id': g.id,
    'ended_at': g.endedAt.millisecondsSinceEpoch,
    'player_side': g.playerSide.name,
    'bot_level': g.botLevel,
    'time_control': g.timeControl.encode(),
    'outcome': Outcome.toPgnString(g.result.outcome),
    'player_result': g.playerResult.name,
    'termination': g.result.termination.name,
    'pgn': g.pgn,
    'final_fen': g.finalFen,
    'plies': g.plies,
    'duration_ms': g.duration.inMilliseconds,
    'opponent': g.opponent,
    'rating_change': g.ratingChange,
  };

  static FinishedGame _fromRow(Map<String, Object?> r) => FinishedGame(
    id: r['id']! as String,
    endedAt: DateTime.fromMillisecondsSinceEpoch(
      r['ended_at']! as int,
      isUtc: true,
    ),
    playerSide: Side.values.byName(r['player_side']! as String),
    botLevel: r['bot_level']! as int,
    timeControl: TimeControl.parse(r['time_control']! as String),
    result: GameResult(
      Outcome.fromPgn(r['outcome']! as String)!,
      Termination.values.byName(r['termination']! as String),
    ),
    pgn: r['pgn']! as String,
    finalFen: r['final_fen']! as String,
    plies: r['plies']! as int,
    duration: Duration(milliseconds: r['duration_ms']! as int),
    opponent: r['opponent'] as String?,
    ratingChange: r['rating_change'] as int?,
  );
}
