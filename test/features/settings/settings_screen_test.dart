import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/core/board/board_theme.dart';
import 'package:langkah/core/board/piece_choice.dart';
import 'package:langkah/features/play_ai/domain/game_setup.dart';
import 'package:langkah/features/settings/presentation/settings_screen.dart';

import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/presentation/game_test_harness.dart';

Future<GameTestHarness> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = GameTestHarness(botEngine());
  await tester.pumpWidget(
    ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(theme: buildAppTheme(), home: const SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

StaticChessboardSettings _preview(WidgetTester tester) =>
    tester.widget<StaticChessboard>(find.byType(StaticChessboard)).settings;

void main() {
  testWidgets('choosing a theme recolours the preview and is saved', (
    tester,
  ) async {
    final h = await _pump(tester);
    expect(_preview(tester).colorScheme, BoardTheme.songket.colorScheme);
    // Each theme card shows its square colours (they once rendered 0 px).
    final swatch = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == BoardTheme.walnut.dark,
    );
    expect(swatch, findsWidgets);
    expect(tester.getSize(swatch.first).height, greaterThan(10));

    await tester.tap(find.text('Graphite'));
    await tester.pumpAndSettle();

    expect(_preview(tester).colorScheme, BoardTheme.graphite.colorScheme);
    expect(h.kv.values['board.theme'], 'graphite');
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a piece set changes the preview and is saved', (
    tester,
  ) async {
    final h = await _pump(tester);

    await tester.tap(find.text('Merida'));
    await tester.pumpAndSettle();

    expect(_preview(tester).pieceAssets, PieceChoice.merida.assets);
    expect(h.kv.values['board.pieces'], 'merida');
  });

  testWidgets('bot speed default is stored with the new-game choices', (
    tester,
  ) async {
    final h = await _pump(tester);

    await tester.ensureVisible(find.text('Fast'));
    await tester.tap(find.text('Fast'));
    await tester.pumpAndSettle();

    final saved = GameSetup.decode(h.kv.values['play_ai.last_setup']!)!;
    expect(saved.botSpeed, BotSpeed.fast);
  });
}
