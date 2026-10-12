import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_setup.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

void main() {
  test('round-trips through its storage string', () {
    final setup = GameSetup(
      level: BotLevel.of(6),
      color: ColorChoice.random,
      timeControl: const TimeControl.minutes(15, 10),
      botSpeed: BotSpeed.fast,
    );
    final back = GameSetup.decode(setup.encode())!;
    expect(back.botSpeed, BotSpeed.fast);
    expect(back.level.number, 6);
    expect(back.color, ColorChoice.random);
    expect(back.timeControl, const TimeControl.minutes(15, 10));
  });

  test('bot speed defaults to natural, also for setups saved before it', () {
    expect(GameSetup.defaults.botSpeed, BotSpeed.natural);
    expect(GameSetup.decode('3|white|5+0')!.botSpeed, BotSpeed.natural);
  });

  test('decode returns null for garbage', () {
    expect(GameSetup.decode('nonsense'), isNull);
    expect(GameSetup.decode('9|white|-'), isNull);
  });

  test('fixed colours resolve to themselves', () {
    final white = GameSetup.defaults.copyWith(color: ColorChoice.white);
    final black = GameSetup.defaults.copyWith(color: ColorChoice.black);
    expect(white.resolveSide(Random(1)), Side.white);
    expect(black.resolveSide(Random(1)), Side.black);
  });

  test('random colour gives both sides over several draws', () {
    final setup = GameSetup.defaults.copyWith(color: ColorChoice.random);
    final random = Random(42);
    final sides = {for (var i = 0; i < 20; i++) setup.resolveSide(random)};
    expect(sides, {Side.white, Side.black});
  });
}
