import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/core/board/board_theme.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/review/domain/position_eval.dart';
import 'package:langkah/features/review/presentation/eval_graph.dart';
import 'package:langkah/features/review/presentation/review_info_line.dart';
import 'package:langkah/features/review/presentation/review_screen.dart';

import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/domain/fake_time_source.dart';
import '../play_ai/presentation/game_test_harness.dart';

/// 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6?? 4. Qxf7#, the player had black.
FinishedGame _game() {
  final c = GameController(
    state: GameState.start(
      id: 'g',
      level: BotLevel.of(2),
      timeControl: TimeControl.unlimited,
      playerSide: Side.black,
      startedAt: DateTime.utc(2026, 10, 12),
    ),
    time: FakeTimeSource(),
    wallClock: () => DateTime.utc(2026, 10, 12, 0, 2),
  );
  for (final uci in ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7']) {
    c.play(Move.parse(uci)!);
  }
  return FinishedGame.fromState(c.state);
}

final _evals = [
  const PositionEval(cp: 20, bestMove: 'e2e4'),
  const PositionEval(cp: 30, bestMove: 'e7e5'),
  const PositionEval(cp: 30, bestMove: 'g1f3'),
  const PositionEval(cp: 40, bestMove: 'b8c6'),
  const PositionEval(cp: 40, bestMove: 'f1c4'),
  const PositionEval(cp: 50, bestMove: 'd8e7'),
  const PositionEval(mate: 1, bestMove: 'h5f7'),
  PositionEval.gameOver(Outcome.whiteWins),
];

Future<GameTestHarness> _pump(
  WidgetTester tester, {
  bool cached = true,
  bool holdEngine = false,
  Size size = const Size(360, 640),
  String? boardTheme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = GameTestHarness(botEngine(holdUntilStop: holdEngine));
  if (cached) h.analysis.saved['g'] = _evals;
  if (boardTheme != null) h.kv.values['board.theme'] = boardTheme;
  await h.history.save(_game());
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const ReviewScreen(gameId: 'g'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('a cached review fits a 360 dp phone', (tester) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(StaticChessboard), findsOneWidget);
    expect(find.byType(EvalGraph), findsOneWidget);
    expect(find.text('Start position'), findsOneWidget);
    expect(find.text('You · Black'), findsOneWidget);
    // Black's only error is 3... Nf6?? (a blunder), marked in the list.
    expect(find.textContaining('??'), findsWidgets);
  });

  testWidgets('"Your next mistake" jumps to it and shows the verdict', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Your next mistake'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3... Nf6'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ReviewInfoLine),
        matching: find.textContaining('Blunder'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('best Qe7'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('mistake buttons are disabled when there is none that way', (
    tester,
  ) async {
    await _pump(tester);
    bool enabled(String tooltip) =>
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(tooltip),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed !=
        null;

    expect(enabled('Your previous mistake'), isFalse); // at the start
    expect(enabled('Your next mistake'), isTrue); // 3... Nf6??
    await tester.tap(find.byTooltip('Your next mistake'));
    await tester.pumpAndSettle();
    expect(enabled('Your next mistake'), isFalse); // none after it
    expect(enabled('Your previous mistake'), isFalse); // none before it
  });

  testWidgets('shows analysis progress while the engine runs', (tester) async {
    final h = await _pump(tester, cached: false, holdEngine: true);

    expect(find.textContaining('Analysing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(h.engine.commands.where((c) => c.startsWith('go')), hasLength(1));

    // Leaving the screen stops the search.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(h.engine.commands, contains('stop'));
  });

  testWidgets('error counts are labelled; zero counts are hidden', (
    tester,
  ) async {
    await _pump(tester);
    final black = find.byKey(const ValueKey('summary-black'));
    expect(
      find.descendant(of: black, matching: find.text('1 Blunder')),
      findsOneWidget,
    );
    expect(find.textContaining('0 '), findsNothing);
    expect(find.textContaining('0?'), findsNothing);
  });

  testWidgets('the eval graph is 120-140 px tall on a normal phone', (
    tester,
  ) async {
    await _pump(tester, size: const Size(390, 844));
    final h = tester.getSize(find.byType(EvalGraph)).height;
    expect(h, inInclusiveRange(120, 140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the review board uses the chosen board theme', (tester) async {
    await _pump(tester, boardTheme: 'walnut');
    final board = tester.widget<StaticChessboard>(
      find.byType(StaticChessboard),
    );
    expect(board.settings.colorScheme, BoardTheme.walnut.colorScheme);
  });
}
