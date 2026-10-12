import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skak/app/theme/app_theme.dart';
import 'package:skak/features/play_ai/application/play_ai_notifier.dart';
import 'package:skak/features/play_ai/data/saved_game_codec.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_controller.dart';
import 'package:skak/features/play_ai/domain/game_state.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';
import 'package:skak/features/play_ai/presentation/game_screen.dart';
import 'package:skak/features/settings/presentation/settings_screen.dart';

import '../application/bot_engine_fake.dart';
import '../domain/fake_time_source.dart';
import 'game_test_harness.dart';

void main() {
  testWidgets('the clock is paused while Settings is open from the game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = GameTestHarness(botEngine());
    // A timed game where it is the player's (White's) turn, clock running.
    final c = GameController(
      state: GameState.start(
        id: 'menu',
        level: BotLevel.of(3),
        timeControl: const TimeControl.minutes(5, 0),
        playerSide: Side.white,
        startedAt: DateTime.utc(2026, 10, 12),
      ),
      time: FakeTimeSource(),
    );
    for (final uci in ['e2e4', 'e7e5']) {
      c.play(Move.parse(uci)!);
    }
    h.kv.values['play_ai.saved_game'] = encodeSavedGame(c.state, Duration.zero);
    final router = GoRouter(
      initialLocation: '/play',
      routes: [
        GoRoute(path: '/play', builder: (_, _) => const GameScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    await container.read(playAiProvider.notifier).resumeSaved();
    await tester.pump(const Duration(milliseconds: 100));
    bool paused() => container.read(playAiProvider)!.game.clock!.isPaused;
    expect(paused(), isFalse);

    await tester.tap(find.byTooltip('Game menu'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(paused(), isTrue);

    router.pop();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(paused(), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
