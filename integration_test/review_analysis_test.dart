// On-device: analyse a saved 40-move game end to end with the real engine,
// then reopen it from the cache. Prints `[review]` timing lines.
// Run: flutter test integration_test/review_analysis_test.dart -d <device>
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:langkah/core/storage/app_database.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/play_ai/application/play_ai_providers.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/domain/time_source.dart';
import 'package:langkah/features/review/application/review_notifier.dart';
import 'package:sqflite/sqflite.dart';

/// 80 plies of random (but legal) moves, then resignation.
FinishedGame _fortyMoveGame() {
  final rng = Random(3);
  final c = GameController(
    state: GameState.start(
      id: 'device-review',
      level: BotLevel.of(3),
      timeControl: TimeControl.unlimited,
      playerSide: Side.white,
      startedAt: DateTime.now(),
    ),
    time: MonotonicTimeSource(),
  );
  while (c.state.moves.length < 80 && !c.state.isOver) {
    final p = c.state.position;
    final moves = [
      for (final e in p.legalMoves.entries)
        for (final to in e.value.squares) NormalMove(from: e.key, to: to),
    ];
    var m = moves[rng.nextInt(moves.length)];
    if (p.board.roleAt(m.from) == Role.pawn &&
        (m.to.rank == Rank.first || m.to.rank == Rank.eighth)) {
      m = m.withPromotion(Role.queen);
    }
    c.play(m);
  }
  if (!c.state.isOver) c.resign();
  return FinishedGame.fromState(c.state);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('analyses a full game, then opens it from the cache', (
    tester,
  ) async {
    final path = '${await getDatabasesPath()}/review_test.db';
    await deleteDatabase(path);
    final db = await openAppDatabase(databaseFactory, path);
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final game = _fortyMoveGame();
    await c.read(historyRepositoryProvider).save(game);

    final watch = Stopwatch()..start();
    var sub = c.listen(reviewProvider(game.id), (_, _) {});
    while (c.read(reviewProvider(game.id)).evals.length < game.plies + 1 ||
        c.read(reviewProvider(game.id)).analysing) {
      if (watch.elapsed > const Duration(minutes: 3)) fail('analysis stuck');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final analysed = watch.elapsed;
    final state = c.read(reviewProvider(game.id));
    expect(state.reviews, hasLength(game.plies));
    debugPrint(
      '[review] ${game.plies} plies analysed in ${analysed.inMilliseconds} ms '
      '(${reviewMoveTime.inMilliseconds} ms/position); '
      'white ${state.summary(Side.white).accuracy?.toStringAsFixed(1)}%, '
      'black ${state.summary(Side.black).accuracy?.toStringAsFixed(1)}%',
    );
    sub.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Reopen: served from the cache.
    watch.reset();
    sub = c.listen(reviewProvider(game.id), (_, _) {});
    while (c.read(reviewProvider(game.id)).evals.length < game.plies + 1) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    debugPrint(
      '[review] reopened from cache in ${watch.elapsedMilliseconds} ms',
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    sub.close();
    c.dispose();
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
