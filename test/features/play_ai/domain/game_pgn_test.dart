import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_pgn.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';

import 'fake_time_source.dart';

GameController _game({Side player = Side.white, Position? initial}) =>
    GameController(
      state: GameState.start(
        id: 'g',
        level: BotLevel.of(5),
        timeControl: const TimeControl.minutes(3, 2),
        playerSide: player,
        startedAt: DateTime.utc(2026, 10, 12),
        initial: initial ?? Chess.initial,
      ),
      time: FakeTimeSource(),
      wallClock: () => DateTime.utc(2026, 10, 12, 0, 10),
    );

void main() {
  test('export then parse gives the same moves and result', () {
    final c = _game();
    for (final uci in [
      'e2e4',
      'e7e5',
      'f1c4',
      'b8c6',
      'd1h5',
      'g8f6',
      'h5f7',
    ]) {
      c.play(Move.parse(uci)!);
    }
    expect(c.state.isOver, isTrue); // scholar's mate

    final pgn = gamePgn(c.state);
    final parsed = PgnGame.parsePgn(pgn);

    expect(
      parsed.moves.mainline().map((n) => n.san).toList(),
      c.state.moves.map((m) => m.san).toList(),
    );
    expect(parsed.headers['Result'], '1-0');
    expect(Outcome.fromPgn(parsed.headers['Result']), Outcome.whiteWins);

    // Replaying the SAN with dartchess reaches the same final position.
    Position p = PgnGame.startingPosition(parsed.headers);
    for (final node in parsed.moves.mainline()) {
      p = p.play(p.parseSan(node.san)!);
    }
    expect(p.fen, c.state.position.fen);
  });

  test('headers name the players, date, time control and termination', () {
    final c = _game(player: Side.black)..resign();
    final headers = PgnGame.parsePgn(gamePgn(c.state)).headers;
    expect(headers['White'], 'Stockfish level 5');
    expect(headers['Black'], 'You');
    expect(headers['Date'], '2026.10.12');
    expect(headers['TimeControl'], '180+2');
    expect(headers['Result'], '1-0');
    expect(headers['Termination'], 'Resignation');
  });

  test('an in-progress game has result *', () {
    final c = _game()..play(Move.parse('e2e4')!);
    final headers = PgnGame.parsePgn(gamePgn(c.state)).headers;
    expect(headers['Result'], '*');
  });

  test('a custom start position is written as FEN with SetUp', () {
    const fen = '7k/8/8/8/8/8/R7/7K w - - 0 1';
    final c = _game(initial: Chess.fromSetup(Setup.parseFen(fen)))
      ..play(Move.parse('a2a8')!);
    final parsed = PgnGame.parsePgn(gamePgn(c.state));
    expect(parsed.headers['FEN'], fen);
    expect(parsed.headers['SetUp'], '1');
    expect(parsed.moves.mainline().single.san, 'Ra8+');
  });
}
