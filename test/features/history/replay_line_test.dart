import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/history/domain/replay_line.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_pgn.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';

import '../play_ai/domain/fake_time_source.dart';

void main() {
  test('replays every position of a saved PGN', () {
    final c = GameController(
      state: GameState.start(
        id: 'r',
        level: BotLevel.of(1),
        timeControl: TimeControl.unlimited,
        playerSide: Side.white,
        startedAt: DateTime.utc(2026),
      ),
      time: FakeTimeSource(),
    );
    for (final uci in ['e2e4', 'd7d5', 'e4d5', 'd8d5', 'b1c3']) {
      c.play(Move.parse(uci)!);
    }

    final line = replayPgn(gamePgn(c.state));

    expect(line.sans, ['e4', 'd5', 'exd5', 'Qxd5', 'Nc3']);
    expect(line.fens, hasLength(6));
    expect(line.fens.first, Chess.initial.fen);
    expect(line.fens.last, c.state.position.fen);
    expect(line.lastMoves.first, isNull);
    expect(line.lastMoves[3]!.uci, 'e4d5');
  });
}
