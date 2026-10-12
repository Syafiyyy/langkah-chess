import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_controller.dart';
import 'package:skak/features/play_ai/domain/game_result.dart';
import 'package:skak/features/play_ai/domain/game_state.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

import 'fake_time_source.dart';

Duration _s(int seconds) => Duration(seconds: seconds);

void main() {
  late FakeTimeSource time;
  late List<GameState> finished;

  GameController controller({
    Side player = Side.white,
    TimeControl timeControl = const TimeControl.minutes(3, 2),
    Position? initial,
  }) {
    return GameController(
      state: GameState.start(
        id: 'g1',
        level: BotLevel.of(1),
        timeControl: timeControl,
        playerSide: player,
        startedAt: DateTime.utc(2026, 10, 12, 9),
        initial: initial ?? Chess.initial,
      ),
      time: time,
      wallClock: () => DateTime.utc(2026, 10, 12, 9, 5),
      onFinished: finished.add,
    );
  }

  void playAll(GameController c, List<String> ucis) {
    for (final uci in ucis) {
      expect(c.play(Move.parse(uci)!), isTrue, reason: uci);
    }
  }

  setUp(() {
    time = FakeTimeSource();
    finished = [];
  });

  group('moves', () {
    test('records UCI and SAN and advances the position', () {
      final c = controller();
      playAll(c, ['e2e4', 'e7e5', 'g1f3']);
      expect(c.state.moves.map((m) => m.uci), ['e2e4', 'e7e5', 'g1f3']);
      expect(c.state.moves.map((m) => m.san), ['e4', 'e5', 'Nf3']);
      expect(c.state.positions, hasLength(4));
      expect(c.state.position.turn, Side.black);
    });

    test('rejects an illegal move and keeps the state', () {
      final c = controller();
      final before = c.state;
      expect(c.play(Move.parse('e2e5')!), isFalse);
      expect(c.state, same(before));
    });

    test('castling by king-onto-rook is stored as the king move', () {
      final c = controller(
        initial: Chess.fromSetup(
          Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
        ),
      );
      expect(c.play(Move.parse('e1h1')!), isTrue);
      expect(c.state.moves.single.uci, 'e1g1');
      expect(c.state.moves.single.san, 'O-O');
    });

    test('capture-promotion keeps the chosen piece', () {
      final c = controller(
        initial: Chess.fromSetup(
          Setup.parseFen('1r5k/P7/8/8/8/8/8/7K w - - 0 1'),
        ),
      );
      expect(c.play(Move.parse('a7b8n')!), isTrue);
      expect(c.state.moves.single.uci, 'a7b8n');
      expect(c.state.moves.single.san, 'axb8=N');
    });

    test('no moves are accepted after the game ends', () {
      final c = controller()..resign();
      expect(c.play(Move.parse('e2e4')!), isFalse);
    });
  });

  group('results', () {
    test('checkmate ends the game and stops the clock', () {
      final c = controller();
      playAll(c, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      expect(c.state.result?.outcome, Outcome.blackWins);
      expect(c.state.result?.termination, Termination.checkmate);
      expect(c.state.clock?.running, isNull);
      expect(c.state.endedAt, DateTime.utc(2026, 10, 12, 9, 5));
    });

    test('threefold repetition by knight shuffles', () {
      final c = controller();
      const shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      playAll(c, shuffle);
      expect(c.state.isOver, isFalse);
      playAll(c, shuffle);
      expect(c.state.result?.termination, Termination.threefoldRepetition);
    });

    test('lost castling rights make positions different for repetition', () {
      final c = controller();
      // Same placement after plies 2, 6 and 10, but only ply 2 still has
      // castling rights, so it is not the same position: no draw yet.
      playAll(c, ['e2e4', 'e7e5', 'e1e2', 'e8e7', 'e2e1', 'e7e8']);
      playAll(c, ['e1e2', 'e8e7', 'e2e1', 'e7e8']);
      expect(c.state.isOver, isFalse);
      // Plies 4, 8 and 12 are identical (no rights left): draw.
      playAll(c, ['e1e2', 'e8e7']);
      expect(c.state.result?.termination, Termination.threefoldRepetition);
    });

    test('resignation: the player loses', () {
      final c = controller(player: Side.black)..resign();
      expect(c.state.result?.outcome, Outcome.whiteWins);
      expect(c.state.result?.termination, Termination.resignation);
    });

    test('onFinished fires exactly once', () {
      final c = controller()..resign();
      c
        ..resign()
        ..checkFlag();
      time.advance(_s(1000));
      c.checkFlag();
      expect(finished, hasLength(1));
      expect(finished.single.result?.termination, Termination.resignation);
    });
  });

  group('clock', () {
    test('starts after white\'s first move, on black', () {
      final c = controller();
      time.advance(_s(30)); // white thinks before the clock starts
      playAll(c, ['e2e4']);
      expect(c.state.clock!.running, Side.black);
      time.advance(_s(4));
      expect(c.state.clock!.remaining(Side.white, time.now()), _s(180));
      expect(c.state.clock!.remaining(Side.black, time.now()), _s(176));
    });

    test('adds the increment after each timed move', () {
      final c = controller();
      playAll(c, ['e2e4']);
      time.advance(_s(5));
      playAll(c, ['e7e5']);
      expect(c.state.clock!.remaining(Side.black, time.now()), _s(177));
      expect(c.state.clock!.running, Side.white);
    });

    test('flag: checkFlag ends the game by timeout', () {
      final c = controller();
      playAll(c, ['e2e4']);
      time.advance(_s(181));
      expect(c.checkFlag(), isTrue);
      expect(c.state.result?.outcome, Outcome.whiteWins);
      expect(c.state.result?.termination, Termination.timeout);
      expect(finished, hasLength(1));
    });

    test('a move after the flag fell is rejected and ends the game', () {
      final c = controller();
      playAll(c, ['e2e4']);
      time.advance(_s(200));
      expect(c.play(Move.parse('e7e5')!), isFalse);
      expect(c.state.result?.termination, Termination.timeout);
    });

    test('flag against a lone king is a draw', () {
      final c = controller(
        player: Side.black,
        initial: Chess.fromSetup(
          Setup.parseFen('7k/8/8/8/8/8/q7/7K w - - 0 1'),
        ),
      );
      playAll(c, ['h1g1']); // white's first move starts black's clock
      time.advance(_s(181));
      c.checkFlag();
      // Black flagged, but white has a lone king: draw.
      expect(c.state.result?.outcome, Outcome.draw);
      expect(c.state.result?.reason, 'Timeout vs insufficient material');
    });

    test('pause stops the clock; resume continues', () {
      final c = controller();
      playAll(c, ['e2e4']);
      time.advance(_s(10));
      c.pause();
      time.advance(_s(500));
      expect(c.checkFlag(), isFalse);
      c.resume();
      time.advance(_s(5));
      expect(c.state.clock!.remaining(Side.black, time.now()), _s(165));
    });

    test('unlimited games have no clock and never flag', () {
      final c = controller(timeControl: TimeControl.unlimited);
      playAll(c, ['e2e4']);
      time.advance(_s(100000));
      expect(c.state.clock, isNull);
      expect(c.checkFlag(), isFalse);
    });
  });

  group('takeback', () {
    test('undoes the bot reply and the player move', () {
      final c = controller();
      playAll(c, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);
      expect(c.takeback(), isTrue);
      expect(c.state.moves.map((m) => m.uci), ['e2e4', 'e7e5']);
      expect(c.state.position.turn, Side.white);
      expect(c.state.positions, hasLength(3));
    });

    test('while the bot is to move, undoes only the player move', () {
      final c = controller();
      playAll(c, ['e2e4', 'e7e5', 'g1f3']);
      time.advance(_s(4)); // bot thinking time
      expect(c.takeback(), isTrue);
      expect(c.state.moves.map((m) => m.uci), ['e2e4', 'e7e5']);
      // The bot's clock is charged but gets no increment; player runs again.
      final clock = c.state.clock!;
      expect(clock.running, Side.white);
      expect(clock.remaining(Side.black, time.now()), _s(178)); // 180 + 2 - 4
    });

    test('is refused when the player has not moved yet', () {
      final c = controller(player: Side.black);
      playAll(c, ['e2e4']);
      expect(c.takeback(), isFalse);
      expect(c.state.moves, hasLength(1));
    });

    test('is refused after the game ended', () {
      final c = controller();
      playAll(c, ['e2e4', 'e7e5']);
      c.resign();
      expect(c.takeback(), isFalse);
    });

    test('undoing white\'s first move stops the clock again', () {
      final c = controller();
      playAll(c, ['e2e4', 'e7e5']);
      expect(c.takeback(), isTrue);
      expect(c.state.moves, isEmpty);
      expect(c.state.clock!.running, isNull);
    });

    test('repetition count follows the undone positions', () {
      final c = controller();
      const shuffle = ['g1f3', 'g8f6', 'f3g1', 'f6g8'];
      playAll(c, [...shuffle, 'g1f3', 'g8f6', 'f3g1']);
      c.takeback(); // back to the start position (2 occurrences)
      playAll(c, ['f3g1', 'f6g8']);
      expect(c.state.result?.termination, Termination.threefoldRepetition);
    });
  });
}
