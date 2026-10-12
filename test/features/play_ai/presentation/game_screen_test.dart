import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/application/play_ai_notifier.dart';
import 'package:langkah/features/play_ai/data/saved_game_codec.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_setup.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/presentation/game_screen.dart';

import '../application/bot_engine_fake.dart';
import 'game_test_harness.dart';

/// Loads a game that starts at [fen] (via the autosave path) and shows it.
Future<ProviderContainer> _openGame(
  WidgetTester tester,
  GameTestHarness h, {
  String? fen,
  TimeControl tc = TimeControl.unlimited,
}) async {
  final state = GameState.start(
    id: 'test',
    level: BotLevel.of(3),
    timeControl: tc,
    playerSide: Side.white,
    startedAt: DateTime.utc(2026, 10, 12),
    initial: fen == null ? Chess.initial : Chess.fromSetup(Setup.parseFen(fen)),
  );
  h.kv.values['play_ai.saved_game'] = encodeSavedGame(state, Duration.zero);
  await tester.pumpWidget(h.wrap(const GameScreen()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GameScreen)),
  );
  await container.read(playAiProvider.notifier).resumeSaved();
  await tester.pumpAndSettle();
  return container;
}

/// Taps the centre of [square] on a white-oriented board.
Future<void> _tapSquare(WidgetTester tester, Square square) async {
  final board = find.byType(Chessboard);
  final topLeft = tester.getTopLeft(board);
  final size = tester.getSize(board).width / 8;
  final offset =
      topLeft +
      Offset(
        (square.file.value + 0.5) * size,
        (7 - square.rank.value + 0.5) * size,
      );
  await tester.tapAt(offset);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('game screen shows board, players, moves and controls', (
    tester,
  ) async {
    final h = GameTestHarness(botEngine());
    await _openGame(tester, h);

    expect(find.byType(Chessboard), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Casual'), findsOneWidget);
    expect(find.text('Level 3 · Bot'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('Moves appear here'), findsOneWidget);
    expect(find.text('Takeback'), findsOneWidget);
    expect(find.text('Resign'), findsOneWidget);
  });

  testWidgets('promotion picker: choosing a queen plays a7a8q', (tester) async {
    final h = GameTestHarness(botEngine(script: ['h8g8']));
    final c = await _openGame(tester, h, fen: '7k/P7/8/8/8/8/8/K7 w - - 0 1');

    await _tapSquare(tester, Square.a7);
    await _tapSquare(tester, Square.a8);
    expect(c.read(playAiProvider)!.game.moves, isEmpty); // picker is open
    await _tapSquare(tester, Square.a8); // queen sits on the target square
    await tester.pumpAndSettle();

    final moves = c.read(playAiProvider)!.game.moves;
    expect(moves.first.uci, 'a7a8q');
    expect(moves.first.san, 'a8=Q+');
  });

  testWidgets('game-over sheet appears after resigning', (tester) async {
    final h = GameTestHarness(botEngine());
    await _openGame(tester, h);

    await tester.tap(find.text('Resign'));
    await tester.pumpAndSettle();
    expect(find.text('Resign this game?'), findsOneWidget);
    await tester.tap(find.text('Resign game'));
    await tester.pumpAndSettle();

    expect(find.text('You lost'), findsOneWidget);
    expect(find.text('Play rematch (swap colours)'), findsOneWidget);
    expect(h.history.saved, hasLength(1));
  });

  testWidgets('rematch swaps colours', (tester) async {
    final h = GameTestHarness(botEngine());
    final c = await _openGame(tester, h);
    c.read(playAiProvider.notifier).resign();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play rematch (swap colours)'));
    await tester.pumpAndSettle();

    final game = c.read(playAiProvider)!.game;
    expect(game.playerSide, Side.black);
    expect(game.level.number, 3);
    expect(game.isOver, isFalse);
    expect(
      GameSetup.decode(h.kv.values['play_ai.last_setup']!)!.color,
      ColorChoice.black,
    );
  });

  testWidgets('fits a 360 dp wide phone with clocks', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = GameTestHarness(botEngine());
    await _openGame(tester, h, tc: const TimeControl.minutes(5, 3));

    expect(tester.takeException(), isNull);
    expect(find.text('5:00'), findsNWidgets(2));

    // The game-over sheet (with "Review game") fits too.
    final c = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    c.read(playAiProvider.notifier).resign();
    await tester.pumpAndSettle();
    expect(find.text('Review game'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Close the screen so the flag timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
