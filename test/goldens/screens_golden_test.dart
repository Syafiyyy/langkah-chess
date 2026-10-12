// Goldens for the main screens at 390x844 (a common phone size).
// Update: flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/app/theme/app_theme.dart';
import 'package:skak/features/history/domain/finished_game.dart';
import 'package:skak/features/home/presentation/home_screen.dart';
import 'package:skak/features/play_ai/application/play_ai_notifier.dart';
import 'package:skak/features/play_ai/data/saved_game_codec.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_controller.dart';
import 'package:skak/features/play_ai/domain/game_state.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';
import 'package:skak/features/play_ai/presentation/game_screen.dart';
import 'package:skak/features/review/domain/position_eval.dart';
import 'package:skak/features/review/presentation/review_screen.dart';

import '../features/home/finished_games.dart';
import '../features/play_ai/application/bot_engine_fake.dart';
import '../features/play_ai/domain/fake_time_source.dart';
import '../features/play_ai/presentation/game_test_harness.dart';
import 'golden_helpers.dart';

const _size = Size(390, 844);

GameState _played(List<String> ucis, {TimeControl? tc, Side? player}) {
  final c = GameController(
    state: GameState.start(
      id: 'golden',
      level: BotLevel.of(3),
      timeControl: tc ?? const TimeControl.minutes(10, 0),
      playerSide: player ?? Side.white,
      startedAt: DateTime.utc(2026, 10, 12, 9),
    ),
    time: FakeTimeSource(),
    wallClock: () => DateTime.utc(2026, 10, 12, 9, 4),
  );
  for (final uci in ucis) {
    c.play(Move.parse(uci)!);
  }
  return c.state;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  GameTestHarness h,
  Widget screen, {
  List<Object> extra = const [],
}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadPieces(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...h.overrides, ...extra.cast()],
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    useTolerantGoldens('test/goldens/screens_golden_test.dart');
    await loadIconFont();
  });

  testWidgets('home', (tester) async {
    // Recent games with one reviewed game, so the lower half is populated.
    final h = GameTestHarness(botEngine());
    for (final g in [
      finishedGame('a', day: 1, kind: 'loss'),
      finishedGame('b', day: 2, kind: 'draw'),
      finishedGame('c', day: 3, kind: 'win'),
    ]) {
      await h.history.save(g);
    }
    h.analysis.saved['c'] = [
      const PositionEval(cp: 0),
      const PositionEval(cp: 0),
      const PositionEval(cp: 0),
      const PositionEval(mate: -1),
      PositionEval.gameOver(Outcome.blackWins),
    ];
    await _pumpScreen(tester, h, const HomeScreen());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/home.png'),
    );
  });

  testWidgets('game', (tester) async {
    final h = GameTestHarness(botEngine());
    final game = _played([
      'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5', //
    ]);
    h.kv.values['play_ai.saved_game'] = encodeSavedGame(game, Duration.zero);
    await _pumpScreen(tester, h, const GameScreen());
    final c = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    await c.read(playAiProvider.notifier).resumeSaved();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(); // paint the move strip scrolled to the latest move
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game.png'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('review', (tester) async {
    final h = GameTestHarness(botEngine());
    final state = _played(
      ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      tc: TimeControl.unlimited,
      player: Side.black,
    );
    await h.history.save(FinishedGame.fromState(state));
    final evals = [
      const PositionEval(cp: 20, bestMove: 'e2e4'),
      const PositionEval(cp: 30, bestMove: 'e7e5'),
      const PositionEval(cp: 30, bestMove: 'g1f3'),
      const PositionEval(cp: 40, bestMove: 'b8c6'),
      const PositionEval(cp: 40, bestMove: 'f1c4'),
      const PositionEval(cp: 50, bestMove: 'd8e7'),
      const PositionEval(mate: 1, bestMove: 'h5f7'),
      PositionEval.gameOver(Outcome.whiteWins),
    ];
    h.analysis.saved['golden'] = evals;
    await _pumpScreen(tester, h, const ReviewScreen(gameId: 'golden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your next mistake'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ReviewScreen),
      matchesGoldenFile('goldens/review.png'),
    );
  });
}
