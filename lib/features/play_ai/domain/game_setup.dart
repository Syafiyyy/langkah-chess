import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'bot_level.dart';
import 'time_control.dart';

/// The colour the player asked for.
enum ColorChoice { white, black, random }

/// Natural: the bot pauses like a person thinking. Fast: it moves as soon as
/// the engine answers.
enum BotSpeed { natural, fast }

/// What the player picked in the new-game sheet.
class GameSetup {
  const GameSetup({
    required this.level,
    required this.color,
    required this.timeControl,
    this.botSpeed = BotSpeed.natural,
  });

  static final GameSetup defaults = GameSetup(
    level: BotLevel.of(2),
    color: ColorChoice.white,
    timeControl: const TimeControl.minutes(10, 0),
  );

  final BotLevel level;
  final ColorChoice color;
  final TimeControl timeControl;
  final BotSpeed botSpeed;

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
    BotSpeed? botSpeed,
  }) => GameSetup(
    level: level ?? this.level,
    color: color ?? this.color,
    timeControl: timeControl ?? this.timeControl,
    botSpeed: botSpeed ?? this.botSpeed,
  );

  /// Storage form: `level|color|timeControl|speed`, e.g.
  /// `3|random|5+0|natural`. Setups saved before speed existed have 3 parts.
  String encode() =>
      '${level.number}|${color.name}|${timeControl.encode()}|${botSpeed.name}';

  /// Inverse of [encode]; null if [text] is not a valid setup.
  static GameSetup? decode(String text) {
    final parts = text.split('|');
    if (parts.length != 3 && parts.length != 4) return null;
    final speed = parts.length == 4
        ? BotSpeed.values.asNameMap()[parts[3]]
        : BotSpeed.natural;
    if (speed == null) return null;
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
        botSpeed: speed,
      );
    } on FormatException {
      return null;
    }
  }
}
