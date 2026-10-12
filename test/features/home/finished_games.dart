import 'package:dartchess/dartchess.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';

import '../play_ai/domain/fake_time_source.dart';

/// A finished game of [kind]: a win is fool's mate with the player as
/// Black, a loss is a resignation, a draw is bare kings.
FinishedGame finishedGame(
  String id, {
  required int day,
  required String kind, // 'win' | 'loss' | 'draw'
}) {
  final player = kind == 'win' ? Side.black : Side.white;
  final c = GameController(
    state: GameState.start(
      id: id,
      level: BotLevel.of(day % 8 + 1),
      timeControl: TimeControl.unlimited,
      playerSide: player,
      startedAt: DateTime.utc(2026, 10, day),
      initial: kind == 'draw'
          ? Chess.fromSetup(Setup.parseFen('k7/8/1K6/8/8/8/8/8 w - - 0 1'))
          : Chess.initial,
    ),
    time: FakeTimeSource(),
    wallClock: () => DateTime.utc(2026, 10, day, 1),
  );
  switch (kind) {
    case 'win': // fool's mate: black (the player) mates
      for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        c.play(Move.parse(uci)!);
      }
    case 'loss':
      c.resign();
    case 'draw': // bare kings: insufficient material after any move
      c.play(Move.parse('b6c6')!);
  }
  return FinishedGame.fromState(c.state);
}
