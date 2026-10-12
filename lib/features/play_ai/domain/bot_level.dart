import 'dart:math' as math;

/// One bot strength level and how it maps to Stockfish 19 options.
///
/// Stockfish's `UCI_Elo` only goes down to 1320 (range 1320..3190, read from
/// the engine's `uci` output), so levels below that use `Skill Level` (0..20)
/// with a small depth cap instead. Every level sets `UCI_LimitStrength` and
/// `Skill Level`, so switching levels never leaves an old option active.
///
/// Ratings are rough estimates (Lichess-style labels), not measured values.
class BotLevel {
  const BotLevel._(
    this.number,
    this.approxRating,
    this.engineOptions,
    this.moveTime, {
    this.depth,
  });

  /// 1 (weakest) to 8 (full strength).
  final int number;

  /// Approximate rating shown to the player.
  final int approxRating;

  /// UCI options to set before the bot searches.
  final Map<String, String> engineOptions;

  /// Search time per move when the clock allows it.
  final Duration moveTime;

  /// Optional depth cap (`go depth n`), used by the weak levels.
  final int? depth;

  /// "Level n · ~rating".
  String get label => 'Level $number · ~$approxRating';

  static BotLevel of(int number) => all[number - 1];

  static const List<BotLevel> all = [
    BotLevel._(1, 800, _skill0, Duration(milliseconds: 100), depth: 1),
    BotLevel._(2, 1000, _skill3, Duration(milliseconds: 150), depth: 2),
    BotLevel._(3, 1200, _skill6, Duration(milliseconds: 250), depth: 4),
    BotLevel._(4, 1400, _elo1400, Duration(milliseconds: 400)),
    BotLevel._(5, 1700, _elo1700, Duration(milliseconds: 600)),
    BotLevel._(6, 2000, _elo2000, Duration(milliseconds: 800)),
    BotLevel._(7, 2400, _elo2400, Duration(milliseconds: 1000)),
    BotLevel._(8, 3000, _full, Duration(milliseconds: 1500)),
  ];

  static const _skill0 = {'UCI_LimitStrength': 'false', 'Skill Level': '0'};
  static const _skill3 = {'UCI_LimitStrength': 'false', 'Skill Level': '3'};
  static const _skill6 = {'UCI_LimitStrength': 'false', 'Skill Level': '6'};
  static const _elo1400 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '1400',
    'Skill Level': '20',
  };
  static const _elo1700 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '1700',
    'Skill Level': '20',
  };
  static const _elo2000 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '2000',
    'Skill Level': '20',
  };
  static const _elo2400 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '2400',
    'Skill Level': '20',
  };
  static const _full = {'UCI_LimitStrength': 'false', 'Skill Level': '20'};
}

/// How long the bot may think for its next move.
///
/// In a timed game the bot never spends more than 1/30 of its remaining time
/// plus half its increment, and always gets at least 50 ms. [remaining] is
/// null for untimed games.
Duration botThinkTime(
  BotLevel level, {
  required Duration? remaining,
  required Duration increment,
}) {
  if (remaining == null) return level.moveTime;
  final budgetMs =
      remaining.inMilliseconds ~/ 30 + increment.inMilliseconds ~/ 2;
  final ms = math.max(50, math.min(level.moveTime.inMilliseconds, budgetMs));
  return Duration(milliseconds: ms);
}
