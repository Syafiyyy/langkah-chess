import 'dart:math' as math;

import 'human_style.dart';

/// One bot strength level and how it maps to Stockfish 19.
///
/// Levels 1–4 are human-like: the engine searches at full strength with
/// MultiPV and [style] picks among the candidates (see HumanMovePicker),
/// because Stockfish's own weakening (`Skill Level`, `UCI_Elo` >= 1320) does
/// not blunder like a beginner. Levels 5–7 use `UCI_LimitStrength` +
/// `UCI_Elo` (range 1320..3190). Level 8 is full strength. Every level sets
/// `UCI_LimitStrength` and `Skill Level`, so switching levels never leaves an
/// old option active.
///
/// Ratings are rough labels, calibrated only relative to each other (see
/// docs/STATE.md), not measured against humans.
class BotLevel {
  const BotLevel._(
    this.number,
    this.name,
    this.approxRating,
    this.engineOptions,
    this.moveTime, {
    this.style,
  });

  /// 1 (weakest) to 8 (full strength).
  final int number;

  /// Human description, e.g. "Newcomer".
  final String name;

  /// Approximate rating hint; null for full strength.
  final int? approxRating;

  /// UCI options to set before the bot searches.
  final Map<String, String> engineOptions;

  /// Search time per move when the clock allows it (levels 5–8).
  final Duration moveTime;

  /// Human-like candidate selection; null for levels that play the engine's
  /// best move.
  final HumanStyle? style;

  /// "Level n · Name".
  String get label => 'Level $number · $name';

  /// "~1400", or "Max" for full strength.
  String get ratingHint => approxRating == null ? 'Max' : '~$approxRating';

  static BotLevel of(int number) => all[number - 1];

  static const List<BotLevel> all = [
    BotLevel._(1, 'Newcomer', 300, _full, _humanTime, style: _newcomer),
    BotLevel._(2, 'Beginner', 550, _full, _humanTime, style: _beginner),
    BotLevel._(3, 'Casual', 800, _full, _humanTime, style: _casual),
    BotLevel._(4, 'Improving', 1100, _full, _humanTime, style: _improving),
    BotLevel._(5, 'Club', 1400, _elo1400, Duration(milliseconds: 600)),
    BotLevel._(6, 'Strong club', 1800, _elo1800, Duration(milliseconds: 800)),
    BotLevel._(7, 'Expert', 2200, _elo2200, Duration(milliseconds: 1000)),
    BotLevel._(8, 'Full strength', null, _full, Duration(milliseconds: 1500)),
  ];

  static const _humanTime = Duration(milliseconds: 300);

  static const _newcomer = HumanStyle(
    temperature: 30,
    blunderChance: 0.30,
    bigBlunders: true,
    randomMoveChance: 0.25,
    missMateInOneChance: 0.65,
    searchDepth: 6,
  );
  static const _beginner = HumanStyle(
    temperature: 14,
    blunderChance: 0.15,
    bigBlunders: true,
    randomMoveChance: 0.05,
    missMateInOneChance: 0.35,
    searchDepth: 8,
  );
  static const _casual = HumanStyle(
    temperature: 6,
    blunderChance: 0.06,
    missMateInOneChance: 0.04,
    searchDepth: 10,
  );
  static const _improving = HumanStyle(
    temperature: 3,
    blunderChance: 0.015,
    missMateInOneChance: 0.01,
    searchDepth: 12,
  );

  static const _full = {'UCI_LimitStrength': 'false', 'Skill Level': '20'};
  static const _elo1400 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '1400',
    'Skill Level': '20',
  };
  static const _elo1800 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '1800',
    'Skill Level': '20',
  };
  static const _elo2200 = {
    'UCI_LimitStrength': 'true',
    'UCI_Elo': '2200',
    'Skill Level': '20',
  };
}

/// How long the bot may search for its next move.
///
/// In a timed game the bot never spends more than 1/30 of its remaining time
/// plus half its increment, and always gets at least 50 ms. [remaining] is
/// null for untimed games.
Duration botThinkTime(
  BotLevel level, {
  required Duration? remaining,
  required Duration increment,
}) {
  final cap = level.style?.searchTime ?? level.moveTime;
  if (remaining == null) return cap;
  final budget = safeThinkBudget(remaining: remaining, increment: increment);
  return budget < cap ? budget : cap;
}

/// The most a bot may spend on one move in a timed game (search plus any
/// thinking pause): 1/30 of its remaining time plus half the increment, at
/// least 50 ms.
Duration safeThinkBudget({
  required Duration remaining,
  required Duration increment,
}) {
  final ms = remaining.inMilliseconds ~/ 30 + increment.inMilliseconds ~/ 2;
  return Duration(milliseconds: math.max(50, ms));
}
