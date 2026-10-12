import 'dart:convert';

import 'package:dartchess/dartchess.dart';

import '../domain/bot_level.dart';
import '../domain/chess_clock.dart';
import '../domain/game_state.dart';
import '../domain/time_control.dart';

/// JSON for an in-progress game, so it can be resumed after the app is
/// killed. Moves are stored as UCI and replayed with dartchess on load.
/// Clocks are stored as remaining time at [now]; time while the app was not
/// running is not charged.
String encodeSavedGame(GameState state, Duration now) {
  final clock = state.clock;
  return jsonEncode({
    'v': 1,
    'id': state.id,
    'level': state.level.number,
    'tc': state.timeControl.encode(),
    'player': state.playerSide.name,
    'startedAt': state.startedAt.millisecondsSinceEpoch,
    'fen': state.initialPosition.fen,
    'moves': [for (final m in state.moves) m.uci],
    if (clock != null)
      'clock': {
        'white': clock.remaining(Side.white, now).inMilliseconds,
        'black': clock.remaining(Side.black, now).inMilliseconds,
        'running': clock.running?.name,
      },
  });
}

/// Inverse of [encodeSavedGame]; null if [json] is corrupt or a move is
/// illegal. The restored clock (if any) runs from [now].
GameState? decodeSavedGame(String json, Duration now) {
  try {
    final map = jsonDecode(json) as Map<String, Object?>;
    final timeControl = TimeControl.parse(map['tc']! as String);
    final initial = Chess.fromSetup(Setup.parseFen(map['fen']! as String));
    final positions = <Position>[initial];
    final moves = <MoveRecord>[];
    for (final uci in (map['moves']! as List<Object?>).cast<String>()) {
      final move = Move.parse(uci);
      if (move == null || !positions.last.isLegal(move)) return null;
      final (next, san) = positions.last.makeSan(move);
      positions.add(next);
      moves.add(MoveRecord(uci: uci, san: san));
    }
    final clockMap = map['clock'] as Map<String, Object?>?;
    final running = clockMap?['running'] as String?;
    return GameState(
      id: map['id']! as String,
      level: BotLevel.of(map['level']! as int),
      timeControl: timeControl,
      playerSide: Side.values.byName(map['player']! as String),
      positions: positions,
      moves: moves,
      clock: clockMap == null
          ? null
          : ChessClock.restore(
              white: Duration(milliseconds: clockMap['white']! as int),
              black: Duration(milliseconds: clockMap['black']! as int),
              increment: timeControl.increment,
              running: running == null ? null : Side.values.byName(running),
              now: now,
            ),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        map['startedAt']! as int,
        isUtc: true,
      ),
    );
  } on Object {
    return null;
  }
}
