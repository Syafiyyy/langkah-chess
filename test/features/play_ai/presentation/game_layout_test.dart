import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/application/play_ai_notifier.dart';
import 'package:langkah/features/play_ai/data/saved_game_codec.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/presentation/game_screen.dart';
import 'package:langkah/shared/widgets/board_frame.dart';
import 'package:langkah/shared/widgets/move_list.dart';
import 'package:langkah/shared/widgets/player_bar.dart';
import 'package:langkah/shared/widgets/tile_button.dart';

import '../application/bot_engine_fake.dart';
import '../domain/fake_time_source.dart';
import 'game_test_harness.dart';

/// Opens a saved game with [ucis] already played (player is White).
Future<ProviderContainer> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<String> ucis = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = GameTestHarness(botEngine());
  final c = GameController(
    state: GameState.start(
      id: 'layout',
      level: BotLevel.of(2),
      timeControl: TimeControl.unlimited,
      playerSide: Side.white,
      startedAt: DateTime.utc(2026, 10, 13),
    ),
    time: FakeTimeSource(),
  );
  for (final u in ucis) {
    c.play(Move.parse(u)!);
  }
  h.kv.values['play_ai.saved_game'] = encodeSavedGame(c.state, Duration.zero);
  await tester.pumpWidget(h.wrap(const GameScreen()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GameScreen)),
  );
  await container.read(playAiProvider.notifier).resumeSaved();
  await tester.pumpAndSettle();
  return container;
}

Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

void main() {
  testWidgets('the bot bar names the persona, level as subtitle', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('Level 2 · Bot'), findsOneWidget);
    expect(find.text('Bot'), findsNothing);
  });

  testWidgets('bars hug the board; spare space is balanced', (tester) async {
    await _open(tester);
    final bars = find.byType(PlayerBar);
    final top = _rect(tester, bars.first);
    final bottom = _rect(tester, bars.last);
    final board = _rect(tester, find.byType(BoardFrame));
    final strip = _rect(tester, find.byKey(MoveList.stripKey));
    final appBar = _rect(tester, find.byType(AppBar));

    expect(board.top - top.bottom, lessThanOrEqualTo(12));
    expect(bottom.top - board.bottom, lessThanOrEqualTo(12));
    final above = top.top - appBar.bottom;
    final below = strip.top - bottom.bottom;
    expect((above - below).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('the board does not move when the status line appears', (
    tester,
  ) async {
    final c = await _open(tester, ucis: ['e2e4', 'e7e5']);
    final before = _rect(tester, find.byType(Chessboard));
    c.read(playAiProvider.notifier).viewPly(1);
    await tester.pumpAndSettle();
    expect(find.text('Viewing an earlier position'), findsOneWidget);
    expect(_rect(tester, find.byType(Chessboard)), before);
  });

  testWidgets('fits 360x640 without overflow', (tester) async {
    await _open(
      tester,
      size: const Size(360, 640),
      ucis: ['e2e4', 'e7e5', 'g1f3'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('current move is a compact pill fully inside the strip', (
    tester,
  ) async {
    await _open(
      tester,
      ucis: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', 'd2d3'],
    );
    final pill = _rect(tester, find.byKey(MoveList.selectedPillKey));
    final strip = _rect(tester, find.byKey(MoveList.stripKey));
    expect(pill.height, lessThanOrEqualTo(32));
    expect(pill.width, greaterThan(pill.height)); // a pill, not a circle
    expect(strip.contains(pill.topLeft), isTrue);
    expect(strip.contains(pill.bottomRight), isTrue);
  });

  testWidgets('move strip and tiles share the 16 px gutter', (tester) async {
    await _open(tester);
    final strip = _rect(tester, find.byKey(MoveList.stripKey));
    final tiles = find.byType(TileButton);
    expect(strip.left, 16);
    expect(strip.right, 390 - 16);
    expect(_rect(tester, tiles.first).left, 16);
    expect(_rect(tester, tiles.last).right, 390 - 16);
  });

  testWidgets('a gold dot marks the side to move', (tester) async {
    await _open(tester); // White (the player) to move
    final dot = find.byKey(PlayerBar.toMoveKey);
    expect(dot, findsOneWidget);
    // The player's bar is the bottom one.
    expect(
      find.descendant(of: find.byType(PlayerBar).last, matching: dot),
      findsOneWidget,
    );
  });
}
