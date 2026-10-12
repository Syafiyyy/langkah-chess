// On-device check for Gate 1: full games against the real Stockfish.
// Run: flutter test integration_test/bot_games_test.dart -d <device>
import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skak/core/storage/app_database.dart';
import 'package:skak/features/play_ai/application/play_ai_notifier.dart';
import 'package:skak/features/play_ai/application/play_ai_providers.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_setup.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';
import 'package:sqflite/sqflite.dart';

/// A random-move player against the bot until the game ends (or 300 plies,
/// then resign). Checks every bot turn: exactly one reply, never stuck.
Future<String> _playGame(
  ProviderContainer c,
  GameSetup setup,
  Random rng,
) async {
  final notifier = c.read(playAiProvider.notifier);
  await notifier.start(setup);
  final replies = <int>[];
  final watch = Stopwatch();

  Future<void> waitForBot() async {
    watch
      ..reset()
      ..start();
    while (c.read(playAiProvider)!.botThinking ||
        c.read(playAiProvider)!.game.isBotTurn) {
      if (watch.elapsed > const Duration(seconds: 15)) {
        fail(
          'Bot stuck thinking at ply ${c.read(playAiProvider)!.game.moves.length}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    replies.add(watch.elapsedMilliseconds);
  }

  if (c.read(playAiProvider)!.game.isBotTurn) await waitForBot();
  while (!c.read(playAiProvider)!.game.isOver) {
    final game = c.read(playAiProvider)!.game;
    expect(game.isPlayerTurn, isTrue);
    if (game.moves.length >= 300) {
      notifier.resign();
      break;
    }
    final before = game.moves.length;
    final legal = [
      for (final e in game.position.legalMoves.entries)
        for (final to in e.value.squares) NormalMove(from: e.key, to: to),
    ];
    var move = legal[rng.nextInt(legal.length)];
    if (game.position.board.roleAt(move.from) == Role.pawn &&
        (move.to.rank == Rank.first || move.to.rank == Rank.eighth)) {
      move = move.withPromotion(Role.queen);
    }
    notifier.move(move);
    if (c.read(playAiProvider)!.game.isOver) break;
    await waitForBot();
    final after = c.read(playAiProvider)!.game.moves.length;
    // Player move + exactly one bot move (no duplicate engine replies).
    expect(after, before + 2, reason: 'ply $before');
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final game = c.read(playAiProvider)!.game;
  replies.sort();
  final median = replies.isEmpty ? 0 : replies[replies.length ~/ 2];
  final worst = replies.isEmpty ? 0 : replies.last;
  return 'level ${setup.level.number} ${setup.timeControl.label}: '
      '${Outcome.toPgnString(game.result!.outcome)} ${game.result!.reason}, '
      '${game.moves.length} plies, bot reply median ${median}ms max ${worst}ms';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('three full games: low, high, timed', (tester) async {
    final path = '${await getDatabasesPath()}/gate1_test.db';
    await deleteDatabase(path);
    final db = await openAppDatabase(databaseFactory, path);
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    final rng = Random(7);
    final setups = [
      GameSetup(
        level: BotLevel.of(1),
        color: ColorChoice.black,
        timeControl: TimeControl.unlimited,
        botSpeed: BotSpeed.fast,
      ),
      GameSetup(
        level: BotLevel.of(8),
        color: ColorChoice.white,
        timeControl: TimeControl.unlimited,
        botSpeed: BotSpeed.fast,
      ),
      GameSetup(
        level: BotLevel.of(5),
        color: ColorChoice.white,
        timeControl: const TimeControl.minutes(3, 2),
        botSpeed: BotSpeed.fast,
      ),
    ];
    final rss = <int>[ProcessInfo.currentRss];
    for (final setup in setups) {
      debugPrint('[gate1] ${await _playGame(c, setup, rng)}');
      rss.add(ProcessInfo.currentRss);
    }
    final saved = await c.read(historyRepositoryProvider).list();
    expect(saved, hasLength(setups.length)); // each game saved exactly once
    debugPrint(
      '[gate1] RSS MB: ${rss.map((b) => (b / 1048576).toStringAsFixed(0)).join(' -> ')}',
    );
    c.dispose();
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 15)));
}
