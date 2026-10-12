import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'bot_level.dart';
import 'time_control.dart';

/// The colour the player asked for.
enum ColorChoice { white, black, random }

/// What the player picked in the new-game sheet.
class GameSetup {
  const GameSetup({
    required this.level,
    required this.color,
    required this.timeControl,
  });

  static final GameSetup defaults = GameSetup(
    level: BotLevel.of(2),
    color: ColorChoice.white,
    timeControl: const TimeControl.minutes(10, 0),
  );

  final BotLevel level;
  final ColorChoice color;
  final TimeControl timeControl;

  /// The player's side; random picks uniformly.
  Side resolveSide(Random random) => switch (color) {
    ColorChoice.white => Side.white,
    ColorChoice.black => Side.black,
    ColorChoice.random => random.nextBool() ? Side.white : Side.black,
  };

  GameSetup copyWith({
    BotLevel? level,
    ColorChoice? color,
    TimeControl? timeControl,
  }) => GameSetup(
    level: level ?? this.level,
    color: color ?? this.color,
    timeControl: timeControl ?? this.timeControl,
  );

  /// Storage form: `level|color|timeControl`, e.g. `3|random|5+0`.
  String encode() => '${level.number}|${color.name}|${timeControl.encode()}';

  /// Inverse of [encode]; null if [text] is not a valid setup.
  static GameSetup? decode(String text) {
    final parts = text.split('|');
    if (parts.length != 3) return null;
    final number = int.tryParse(parts[0]);
    final color = ColorChoice.values.asNameMap()[parts[1]];
    if (number == null || number < 1 || number > 8 || color == null) {
      return null;
    }
    try {
      return GameSetup(
        level: BotLevel.of(number),
        color: color,
        timeControl: TimeControl.parse(parts[2]),
      );
    } on FormatException {
      return null;
    }
  }
}
