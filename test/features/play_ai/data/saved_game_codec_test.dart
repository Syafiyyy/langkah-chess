import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/data/saved_game_codec.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';

import '../domain/fake_time_source.dart';

void main() {
  late FakeTimeSource time;

  GameController game({TimeControl tc = const TimeControl.minutes(5, 3)}) =>
      GameController(
        state: GameState.start(
          id: 'saved-1',
          level: BotLevel.of(7),
          timeControl: tc,
          playerSide: Side.black,
          startedAt: DateTime.utc(2026, 10, 12, 8),
        ),
        time: time,
      );

  setUp(() => time = FakeTimeSource());

  test('round-trips moves, setup and clocks', () {
    final c = game();
    for (final uci in ['e2e4', 'c7c5', 'g1f3', 'd7d6']) {
      c.play(Move.parse(uci)!);
      time.advance(const Duration(seconds: 2));
    }
    final json = encodeSavedGame(c.state, time.now());

    time.advance(const Duration(hours: 5)); // app was dead meanwhile
    final back = decodeSavedGame(json, time.now())!;

    expect(back.id, 'saved-1');
    expect(back.level.number, 7);
    expect(back.timeControl, const TimeControl.minutes(5, 3));
    expect(back.playerSide, Side.black);
    expect(back.startedAt, DateTime.utc(2026, 10, 12, 8));
    expect(back.moves.map((m) => m.san), ['e4', 'c5', 'Nf3', 'd6']);
    expect(back.position.fen, c.state.position.fen);
    expect(back.positions, hasLength(5));

    // Time while the app was dead is not charged.
    final clock = back.clock!;
    final original = c.state.clock!;
    final savedAt = time.now() - const Duration(hours: 5);
    expect(clock.running, original.running);
    expect(
      clock.remaining(Side.white, time.now()),
      original.remaining(Side.white, savedAt),
    );
    expect(
      clock.remaining(Side.black, time.now()),
      original.remaining(Side.black, savedAt),
    );
  });

  test('round-trips an untimed game with no moves', () {
    final c = game(tc: TimeControl.unlimited);
    final back = decodeSavedGame(
      encodeSavedGame(c.state, time.now()),
      time.now(),
    )!;
    expect(back.clock, isNull);
    expect(back.moves, isEmpty);
    expect(back.timeControl, TimeControl.unlimited);
  });

  test('returns null for corrupt data', () {
    expect(decodeSavedGame('not json', Duration.zero), isNull);
    expect(decodeSavedGame('{"v":1}', Duration.zero), isNull);
    final c = game()..play(Move.parse('e2e4')!);
    final illegal = encodeSavedGame(
      c.state,
      Duration.zero,
    ).replaceAll('e2e4', 'e2e5');
    expect(decodeSavedGame(illegal, Duration.zero), isNull);
  });
}
