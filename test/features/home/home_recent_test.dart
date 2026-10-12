import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/home/presentation/home_screen.dart';
import 'package:skak/features/review/domain/position_eval.dart';

import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/presentation/game_test_harness.dart';
import 'finished_games.dart';

void main() {
  testWidgets('first use: recent games points to a new game, no stats', (
    tester,
  ) async {
    final h = GameTestHarness(botEngine());
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Recent games'), findsOneWidget);
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('Games'), findsNothing);
    await tester.ensureVisible(find.text('Start a game'));
    await tester.tap(find.text('Start a game'));
    await tester.pumpAndSettle();
    expect(find.text('Start game'), findsOneWidget); // new-game sheet
  });

  testWidgets('shows the last three games, stats and reviewed accuracy', (
    tester,
  ) async {
    final h = GameTestHarness(botEngine());
    for (final g in [
      finishedGame('a', day: 1, kind: 'loss'),
      finishedGame('b', day: 2, kind: 'draw'),
      finishedGame('c', day: 3, kind: 'loss'),
      finishedGame('d', day: 4, kind: 'win'),
    ]) {
      await h.history.save(g);
    }
    h.analysis.saved['d'] = [
      const PositionEval(cp: 0),
      const PositionEval(cp: 0),
      const PositionEval(cp: 0),
      const PositionEval(mate: -1),
      PositionEval.gameOver(Outcome.blackWins),
    ];
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    // Stats: 4 games, 1 win, best accuracy 100%.
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Wins'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Best accuracy'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);

    // Three newest rows; game "a" is not shown.
    expect(find.byKey(const ValueKey('recent-d')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-a')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('recent-d')),
        matching: find.textContaining('100% accuracy'),
      ),
      findsOneWidget,
    );
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('settings has one entry point (the card)', (tester) async {
    final h = GameTestHarness(botEngine());
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Settings'), findsNothing);
    await tester.scrollUntilVisible(find.text('Settings'), 100);
    expect(find.text('Settings'), findsOneWidget);
  });
}
