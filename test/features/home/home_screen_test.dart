import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/features/home/presentation/home_screen.dart';
import 'package:langkah/features/play_ai/data/saved_game_codec.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';

import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/presentation/game_test_harness.dart';

Future<GameTestHarness> _withSavedGame(WidgetTester tester) async {
  final h = GameTestHarness(botEngine());
  final state = GameState.start(
    id: 'unfinished',
    level: BotLevel.of(3),
    timeControl: TimeControl.unlimited,
    playerSide: Side.white,
    startedAt: DateTime.utc(2026, 10, 12),
  );
  h.kv.values['play_ai.saved_game'] = encodeSavedGame(state, Duration.zero);
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  testWidgets('Play vs Bot asks before abandoning an unfinished game', (
    tester,
  ) async {
    final h = await _withSavedGame(tester);

    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();
    expect(find.text('Abandon current game?'), findsOneWidget);

    await tester.tap(find.text('Keep game'));
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsNothing); // no new-game sheet
    expect(h.kv.values.containsKey('play_ai.saved_game'), isTrue);
  });

  testWidgets('abandoning clears the saved game and opens the sheet', (
    tester,
  ) async {
    final h = await _withSavedGame(tester);

    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandon game'));
    await tester.pumpAndSettle();

    expect(find.text('Start game'), findsOneWidget);
    expect(h.kv.values.containsKey('play_ai.saved_game'), isFalse);
    expect(h.history.saved, isEmpty);
  });

  testWidgets('no question when nothing is unfinished', (tester) async {
    final h = GameTestHarness(botEngine());
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();
    expect(find.text('Abandon current game?'), findsNothing);
    expect(find.text('Start game'), findsOneWidget);
  });
}
