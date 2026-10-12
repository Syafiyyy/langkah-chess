import 'package:dartchess/dartchess.dart';

import 'bot_level.dart';
import 'chess_clock.dart';
import 'game_result.dart';
import 'game_setup.dart';
import 'time_control.dart';

/// One played move in both notations.
class MoveRecord {
  const MoveRecord({required this.uci, required this.san});

  /// Standard UCI, castling as a king move (`e1g1`).
  final String uci;
  final String san;
}

/// Immutable snapshot of an offline game against the bot.
class GameState {
  const GameState({
    required this.id,
    required this.level,
    required this.timeControl,
    required this.playerSide,
    required this.positions,
    required this.moves,
    required this.clock,
    required this.startedAt,
    this.botSpeed = BotSpeed.natural,
    this.result,
    this.endedAt,
  });

  /// A new game at [initial] (the standard start unless a test says else).
  factory GameState.start({
    required String id,
    required BotLevel level,
    required TimeControl timeControl,
    required Side playerSide,
    required DateTime startedAt,
    BotSpeed botSpeed = BotSpeed.natural,
    Position initial = Chess.initial,
  }) => GameState(
    id: id,
    level: level,
    timeControl: timeControl,
    playerSide: playerSide,
    positions: [initial],
    moves: const [],
    clock: timeControl.isTimed ? ChessClock.initial(timeControl) : null,
    startedAt: startedAt,
    botSpeed: botSpeed,
  );

  final String id;
  final BotLevel level;
  final TimeControl timeControl;
  final Side playerSide;
  final BotSpeed botSpeed;

  /// Every position from the start; `positions.length == moves.length + 1`.
  final List<Position> positions;
  final List<MoveRecord> moves;

  /// Null for untimed games.
  final ChessClock? clock;

  final GameResult? result;
  final DateTime startedAt;
  final DateTime? endedAt;

  Position get position => positions.last;
  Position get initialPosition => positions.first;
  Side get botSide => playerSide.opposite;
  bool get isOver => result != null;
  bool get isPlayerTurn => !isOver && position.turn == playerSide;
  bool get isBotTurn => !isOver && position.turn == botSide;

  /// The last move as a dartchess move, for highlights.
  Move? get lastMove => moves.isEmpty ? null : Move.parse(moves.last.uci);

  /// How often the current position has occurred (for repetition).
  int get repetitions {
    final key = positionKey(position);
    return positions.where((p) => positionKey(p) == key).length;
  }

  GameState copyWith({
    List<Position>? positions,
    List<MoveRecord>? moves,
    ChessClock? clock,
    GameResult? result,
    DateTime? endedAt,
  }) => GameState(
    id: id,
    level: level,
    timeControl: timeControl,
    playerSide: playerSide,
    positions: positions ?? this.positions,
    moves: moves ?? this.moves,
    clock: clock ?? this.clock,
    startedAt: startedAt,
    botSpeed: botSpeed,
    result: result ?? this.result,
    endedAt: endedAt ?? this.endedAt,
  );
}
