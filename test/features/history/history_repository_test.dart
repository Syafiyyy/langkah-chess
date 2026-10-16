import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/storage/app_database.dart';
import 'package:skak/features/history/data/history_repository.dart';
import 'package:skak/features/history/domain/finished_game.dart';
import 'package:skak/features/play_ai/domain/game_result.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FinishedGame _game(
  String id, {
  required DateTime endedAt,
  Side player = Side.white,
  Outcome outcome = Outcome.whiteWins,
  Termination termination = Termination.checkmate,
  String? opponent,
  int? ratingChange,
}) => FinishedGame(
  id: id,
  endedAt: endedAt,
  playerSide: player,
  botLevel: 3,
  timeControl: const TimeControl.minutes(5, 0),
  result: GameResult(outcome, termination),
  pgn: '[Event "x"]\n\n1. e4 *',
  finalFen: Chess.initial.fen,
  plies: 41,
  duration: const Duration(minutes: 7, seconds: 3),
  opponent: opponent,
  ratingChange: ratingChange,
);

void main() {
  late Database db;
  late HistoryRepository repo;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    repo = SqfliteHistoryRepository(db);
  });

  tearDown(() => db.close());

  test('saves and reads back every field', () async {
    final game = _game('a', endedAt: DateTime.utc(2026, 10, 12, 10));
    await repo.save(game);
    final back = (await repo.byId('a'))!;
    expect(back.endedAt, game.endedAt);
    expect(back.playerSide, Side.white);
    expect(back.botLevel, 3);
    expect(back.timeControl, const TimeControl.minutes(5, 0));
    expect(back.result.outcome, Outcome.whiteWins);
    expect(back.result.termination, Termination.checkmate);
    expect(back.pgn, game.pgn);
    expect(back.finalFen, game.finalFen);
    expect(back.plies, 41);
    expect(back.moveCount, 21);
    expect(back.duration, game.duration);
    expect(back.opponent, isNull);
    expect(back.ratingChange, isNull);
    expect(back.isOnline, isFalse);
    expect(back.opponentLabel, 'Level 3');
  });

  test('online games keep the opponent and rating change', () async {
    await repo.save(
      _game(
        'o',
        endedAt: DateTime.utc(2026, 10, 16),
        outcome: Outcome.draw,
        termination: Termination.agreement,
        opponent: 'gate_b',
        ratingChange: -3,
      ),
    );
    final back = (await repo.byId('o'))!;
    expect(back.opponent, 'gate_b');
    expect(back.ratingChange, -3);
    expect(back.isOnline, isTrue);
    expect(back.opponentLabel, 'vs gate_b');
    expect(back.result.reason, 'Draw by agreement');
  });

  test(
    'a version 2 database gets the online columns and keeps its games',
    () async {
      final dir = await Directory.systemTemp.createTemp('skak_db');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/v2.db';
      final v2 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, _) => db.execute('''
          CREATE TABLE games (
            id TEXT PRIMARY KEY, ended_at INTEGER NOT NULL,
            player_side TEXT NOT NULL, bot_level INTEGER NOT NULL,
            time_control TEXT NOT NULL, outcome TEXT NOT NULL,
            player_result TEXT NOT NULL, termination TEXT NOT NULL,
            pgn TEXT NOT NULL, final_fen TEXT NOT NULL,
            plies INTEGER NOT NULL, duration_ms INTEGER NOT NULL)'''),
        ),
      );
      await v2.insert('games', {
        'id': 'old',
        'ended_at': 0,
        'player_side': 'white',
        'bot_level': 2,
        'time_control': '-',
        'outcome': '1-0',
        'player_result': 'win',
        'termination': 'checkmate',
        'pgn': '',
        'final_fen': Chess.initial.fen,
        'plies': 1,
        'duration_ms': 0,
      });
      await v2.close();

      final db3 = await openAppDatabase(databaseFactoryFfi, path);
      addTearDown(db3.close);
      expect(await db3.getVersion(), 3);
      final old = (await SqfliteHistoryRepository(db3).byId('old'))!;
      expect(old.opponent, isNull);
    },
  );

  test('lists newest first', () async {
    await repo.save(_game('old', endedAt: DateTime.utc(2026, 9, 30)));
    await repo.save(_game('new', endedAt: DateTime.utc(2026, 10, 12)));
    await repo.save(_game('mid', endedAt: DateTime.utc(2026, 10, 5)));
    final ids = (await repo.list()).map((g) => g.id);
    expect(ids, ['new', 'mid', 'old']);
  });

  test('filters wins, losses and draws from the player\'s view', () async {
    final t = DateTime.utc(2026, 10, 12);
    await repo.save(_game('win', endedAt: t)); // white player, white wins
    await repo.save(
      _game('loss', endedAt: t, player: Side.black), // black player loses
    );
    await repo.save(
      _game(
        'draw',
        endedAt: t,
        outcome: Outcome.draw,
        termination: Termination.stalemate,
      ),
    );
    Future<List<String>> ids(HistoryFilter f) async =>
        (await repo.list(filter: f)).map((g) => g.id).toList();
    expect(await ids(HistoryFilter.wins), ['win']);
    expect(await ids(HistoryFilter.losses), ['loss']);
    expect(await ids(HistoryFilter.draws), ['draw']);
    expect(await ids(HistoryFilter.all), hasLength(3));
  });

  test('saving the same game twice keeps one row', () async {
    final game = _game('a', endedAt: DateTime.utc(2026, 10, 12));
    await repo.save(game);
    await repo.save(game);
    expect(await repo.list(), hasLength(1));
  });

  test('byId returns null for an unknown id', () async {
    expect(await repo.byId('nope'), isNull);
  });
}
