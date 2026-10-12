import 'dart:math';

import 'package:dartchess/dartchess.dart';

import '../../../core/engine/engine_service.dart';
import '../domain/bot_level.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
import '../domain/human_move_picker.dart';
import '../domain/thinking_time.dart';

/// Plays the bot's turns for one game at one [level].
///
/// Levels 5–8 play the engine's bestmove. Levels 1–4 ask for MultiPV
/// candidates and let a [HumanMovePicker] choose (one picker per game, so its
/// "no two big blunders in a row" memory lasts the whole game). At natural
/// speed the move is held back until a human-like think time has passed.
class BotMover {
  BotMover({
    required this._engine,
    required this.level,
    required this._random,
    required this._pause,
  }) : _picker = level.style == null
           ? null
           : HumanMovePicker(level.style!, _random);

  final EngineService _engine;
  final BotLevel level;
  final Random _random;
  final Future<void> Function(Duration) _pause;
  final HumanMovePicker? _picker;

  /// The bot's whole turn in [game]: search, pick, and (natural speed) the
  /// thinking pause. [remaining] is the bot's clock (null if untimed); the
  /// search and pause together stay within its safe budget. Returns null if
  /// the engine had no move or [stillWanted] turned false.
  Future<String?> play(
    GameState game, {
    required Duration? remaining,
    required bool Function() stillWanted,
  }) async {
    final watch = Stopwatch()..start();
    final increment = game.timeControl.increment;
    final uci = await move(
      game.position,
      searchTime: botThinkTime(
        level,
        remaining: remaining,
        increment: increment,
      ),
      stillWanted: stillWanted,
    );
    if (uci == null || !stillWanted()) return null;
    if (game.botSpeed == BotSpeed.natural) {
      final pause = pauseAfterSearch(
        target: naturalThinkTime(level, game.position, game.lastMove, _random),
        searched: watch.elapsed,
        budget: remaining == null
            ? null
            : safeThinkBudget(remaining: remaining, increment: increment),
      );
      if (pause > Duration.zero) await _pause(pause);
      if (!stillWanted()) return null;
    }
    return uci;
  }

  /// The bot's move in [position] as UCI, or null if the engine has none.
  /// [searchTime] caps the search. Stops early (returns null) when
  /// [stillWanted] turns false between steps.
  Future<String?> move(
    Position position, {
    required Duration searchTime,
    required bool Function() stillWanted,
  }) async {
    // Set the level before every search: the engine restarts with default
    // options after it was disposed (app detach, hot reload).
    await _engine.setOptions(level.engineOptions);
    if (!stillWanted()) return null;
    final style = level.style;
    final picker = _picker;
    if (style == null || picker == null) {
      final result = await _engine.bestMove(position.fen, moveTime: searchTime);
      return result.bestMove;
    }
    final lines = await _engine.candidates(
      position.fen,
      count: style.candidates,
      moveTime: searchTime,
      depth: style.searchDepth,
    );
    if (!stillWanted() || !position.hasSomeLegalMoves) return null;
    return picker.pick(position, [
      for (final line in lines)
        MoveCandidate(uci: line.pv.first, cp: line.cp, mate: line.mate),
    ]).uci;
  }
}
