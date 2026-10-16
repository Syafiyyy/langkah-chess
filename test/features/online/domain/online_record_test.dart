import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/history/domain/finished_game.dart';
import 'package:skak/features/online/domain/online_record.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/review/domain/game_line.dart';

import '../fake_online_api.dart';

void main() {
  test("Fool's mate becomes a history game the review can replay", () {
    final api = FakeOnlineApi();
    api.addGame(mySide: Side.black, baseMs: 180000, incMs: 2000);
    for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      api.serverMove('g1', uci);
    }
    final ended = DateTime.utc(2026, 10, 16, 12, 3, 30);
    final game = api.copy(api.games['g1']!);
    final finished = ServerGame(
      id: game.id,
      status: game.status,
      mode: game.mode,
      timeBaseMs: game.timeBaseMs,
      incrementMs: game.incrementMs,
      fen: game.fen,
      ply: game.ply,
      whiteMs: game.whiteMs,
      blackMs: game.blackMs,
      whiteId: game.whiteId,
      blackId: game.blackId,
      result: game.result,
      termination: game.termination,
      createdAt: DateTime.utc(2026, 10, 16, 12),
      finishedAt: ended,
    );

    final record = onlineFinishedGame(
      game: finished,
      moves: api.moves['g1']!,
      mySide: Side.black,
      white: 'opponent',
      black: 'me_user',
      ratingChange: 16,
    )!;

    expect(record.id, 'g1');
    expect(record.opponent, 'opponent');
    expect(record.botLevel, 0);
    expect(record.playerSide, Side.black);
    expect(record.playerResult, PlayerResult.win);
    expect(record.result.reason, 'Checkmate');
    expect(record.ratingChange, 16);
    expect(record.timeControl.label, '3+2');
    expect(record.plies, 4);
    expect(record.endedAt, ended);
    expect(record.duration, const Duration(minutes: 3, seconds: 30));
    expect(record.pgn, contains('[White "opponent"]'));
    expect(record.pgn, contains('[Black "me_user"]'));
    expect(record.pgn, contains('[Result "0-1"]'));
    expect(record.pgn, contains('[TimeControl "180+2"]'));
    expect(
      [for (final m in GameLine.fromPgn(record.pgn).moves) m.san],
      ['f3', 'e5', 'g4', 'Qh4#'],
    );
  });

  test('aborted and running games are not history', () {
    final api = FakeOnlineApi()..addGame();
    expect(
      onlineFinishedGame(
        game: api.games['g1']!,
        moves: const <ServerMove>[],
        mySide: Side.white,
        white: 'a',
        black: 'b',
      ),
      isNull,
    );
  });
}
