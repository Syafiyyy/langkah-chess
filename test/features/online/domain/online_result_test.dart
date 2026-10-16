import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/online/domain/online_result.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/play_ai/domain/game_result.dart';

ServerGame _g(GameStatus status, {String? result, String? termination}) =>
    ServerGame(
      id: 'g',
      status: status,
      mode: 'invite',
      timeBaseMs: 300000,
      incrementMs: 0,
      fen: '',
      ply: 3,
      whiteMs: 1,
      blackMs: 1,
      result: result,
      termination: termination,
    );

void main() {
  test('finished games map to the app result types', () {
    final mate = serverResult(
      _g(GameStatus.finished, result: 'black', termination: 'checkmate'),
    )!;
    expect(mate.outcome, Outcome.blackWins);
    expect(mate.termination, Termination.checkmate);

    final agreed = serverResult(
      _g(GameStatus.finished, result: 'draw', termination: 'agreement'),
    )!;
    expect(agreed.outcome, Outcome.draw);
    expect(agreed.reason, 'Draw by agreement');

    final flag = serverResult(
      _g(GameStatus.finished, result: 'draw', termination: 'timeout'),
    )!;
    expect(flag.reason, 'Timeout vs insufficient material');
  });

  test('no result while running or aborted', () {
    expect(serverResult(_g(GameStatus.active)), isNull);
    expect(
      serverResult(_g(GameStatus.aborted, termination: 'aborted')),
      isNull,
    );
  });

  test('aborted games say why', () {
    expect(
      abortReason(_g(GameStatus.aborted, termination: 'aborted')),
      'Game aborted',
    );
    expect(
      abortReason(_g(GameStatus.aborted, termination: 'firstMoveTimeout')),
      'No first move in time',
    );
    expect(
      abortReason(_g(GameStatus.aborted, termination: 'expired')),
      'Nobody joined within 24 hours',
    );
  });
}
