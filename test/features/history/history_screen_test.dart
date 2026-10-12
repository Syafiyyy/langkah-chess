import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/app/theme/app_theme.dart';
import 'package:skak/features/history/domain/finished_game.dart';
import 'package:skak/features/history/presentation/history_screen.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_controller.dart';
import 'package:skak/features/play_ai/domain/game_state.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/domain/fake_time_source.dart';
import '../play_ai/presentation/game_test_harness.dart';

Future<GameTestHarness> _pump(
  WidgetTester tester, {
  bool oneLoss = false,
}) async {
  final h = GameTestHarness(botEngine());
  if (oneLoss) {
    final c = GameController(
      state: GameState.start(
        id: 'lost',
        level: BotLevel.of(2),
        timeControl: TimeControl.unlimited,
        playerSide: Side.white,
        startedAt: DateTime.utc(2026, 10, 12),
      ),
      time: FakeTimeSource(),
      wallClock: () => DateTime.utc(2026, 10, 12, 0, 5),
    )..resign();
    await h.history.save(FinishedGame.fromState(c.state));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(theme: buildAppTheme(), home: const HistoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('first use: says what belongs here and offers to play', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('No games yet'), findsOneWidget);
    expect(find.textContaining('review every move'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Play vs Bot'), findsOneWidget);
  });

  testWidgets('filtered empty: one tap shows all games again', (tester) async {
    await _pump(tester, oneLoss: true);

    await tester.tap(find.text('Wins'));
    await tester.pumpAndSettle();
    expect(find.text('No games match this filter'), findsOneWidget);

    await tester.tap(find.text('Show all games'));
    await tester.pumpAndSettle();
    expect(find.text('No games match this filter'), findsNothing);
    expect(find.textContaining('Resignation'), findsOneWidget);
  });
}
