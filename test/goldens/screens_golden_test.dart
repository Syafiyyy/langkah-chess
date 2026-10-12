// Goldens for the main screens at 390x844 (a common phone size).
// Update: flutter test --update-goldens test/goldens/
@Tags(['golden'])
library;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/home/presentation/home_screen.dart';
import 'package:langkah/features/play_ai/application/play_ai_notifier.dart';
import 'package:langkah/features/play_ai/data/saved_game_codec.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/presentation/game_screen.dart';
import 'package:langkah/features/review/application/review_notifier.dart';
import 'package:langkah/features/review/data/analysis_repository.dart';
import 'package:langkah/features/review/domain/position_eval.dart';
import 'package:langkah/features/review/presentation/review_screen.dart';

import '../features/play_ai/application/bot_engine_fake.dart';
import '../features/play_ai/domain/fake_time_source.dart';
import '../features/play_ai/presentation/game_test_harness.dart';
import 'golden_helpers.dart';

const _size = Size(390, 844);

class _MemoryAnalysis implements AnalysisRepository {
  _MemoryAnalysis(this.saved);
  final Map<String, List<PositionEval>> saved;

  @override
  Future<List<PositionEval>?> load(String gameId, AnalysisKey key) async =>
      saved[gameId];

  @override
  Future<void> save(String id, AnalysisKey key, List<PositionEval> e) async {}
}

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
    await loadAppFonts();
  });

  testWidgets('home', (tester) async {
    final h = GameTestHarness(botEngine());
    h.kv.values['play_ai.saved_game'] = encodeSavedGame(
      _played(['e2e4']),
      Duration.zero,
    );
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
    await _pumpScreen(
      tester,
      h,
      const ReviewScreen(gameId: 'golden'),
      extra: [
        analysisRepositoryProvider.overrideWithValue(
          _MemoryAnalysis({'golden': evals}),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your next mistake'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ReviewScreen),
      matchesGoldenFile('goldens/review.png'),
    );
  });
}
