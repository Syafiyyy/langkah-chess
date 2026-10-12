import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/storage/app_database.dart';
import 'package:langkah/features/history/data/history_repository.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/play_ai/domain/game_result.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FinishedGame _game(
  String id, {
  required DateTime endedAt,
  Side player = Side.white,
  Outcome outcome = Outcome.whiteWins,
  Termination termination = Termination.checkmate,
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
  });

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
