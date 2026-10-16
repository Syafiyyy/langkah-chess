import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/supabase/server_clock.dart';
import 'package:skak/core/supabase/supabase_providers.dart';
import 'package:skak/features/online/application/online_game_notifier.dart';
import 'package:skak/features/online/data/online_api.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/online/presentation/online_game_screen.dart';
import 'package:skak/features/play_ai/application/play_ai_providers.dart';
import 'package:skak/features/play_ai/presentation/game_board.dart';

import '../history/memory_history.dart';
import 'fake_online_api.dart';
import 'online_harness.dart';

Future<FakeOnlineApi> _pump(
  WidgetTester tester, {
  Side mySide = Side.white,
  List<String> moves = const [],
  Size size = const Size(360, 640),
}) async {
  final api = FakeOnlineApi()..addGame(mySide: mySide);
  for (final uci in moves) {
    api.serverMove('g1', uci);
  }
  await pumpOnlinePage(
    tester,
    api,
    const OnlineGameScreen(gameId: 'g1'),
    size: size,
    overrides: [
      serverClockProvider.overrideWithValue(
        ServerClock(localNow: () => api.now),
      ),
      historyRepositoryProvider.overrideWithValue(MemoryHistory()),
    ],
  );
  await tester.pump();
  await tester.pump();
  return api;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('players, clocks and moves fit at 360x640', (tester) async {
    await _pump(tester, moves: ['e2e4', 'e7e5', 'g1f3']);
    expect(find.text('me_user (you)'), findsOneWidget);
    expect(find.text('opponent'), findsOneWidget);
    expect(find.text('Rating 1300'), findsOneWidget);
    expect(find.text('5:00'), findsNWidgets(2));
    expect(find.text('Nf3'), findsOneWidget);
    expect(find.text('Resign'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('before both moved: Abort instead of Resign, first-move '
      'countdown', (tester) async {
    await _pump(tester);
    expect(find.text('Abort'), findsOneWidget);
    expect(find.text('Make your first move: 30s'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Reconnecting in the title while the channel is down', (tester) async {
    final api = await _pump(tester, moves: ['e2e4', 'e7e5']);
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    api.setConnected('g1', true);
    await _settle(tester);
    expect(find.textContaining('Reconnecting'), findsNothing);
    final boardAt = tester.getTopLeft(find.byType(GameBoard));
    api.setConnected('g1', false);
    await tester.pump();
    expect(find.textContaining('Reconnecting'), findsOneWidget);
    // The board must not jump when the connection drops.
    expect(tester.getTopLeft(find.byType(GameBoard)), boardAt);
    await unmount(tester);
  });

  testWidgets("the opponent's draw offer can be accepted", (tester) async {
    final api = await _pump(tester, moves: ['e2e4', 'e7e5']);
    api.setGame(api.copy(api.games['g1']!, drawOfferBy: 'opp'));
    api.hint('g1');
    await _settle(tester);
    expect(find.text('Draw offered'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Accept draw'));
    await _settle(tester);
    expect(api.calls, contains('act acceptDraw'));
    // The game-over sheet opens.
    expect(find.text('Draw'), findsOneWidget);
    expect(find.text('Rating +12'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('resign asks first, then shows the result', (tester) async {
    final api = await _pump(tester, moves: ['e2e4', 'e7e5']);
    await tester.tap(find.text('Resign'));
    await _settle(tester);
    expect(api.count('act resign'), 0);
    await tester.tap(find.text('Resign game'));
    await _settle(tester);
    expect(api.count('act resign'), 1);
    expect(find.text('You lost'), findsOneWidget);
    expect(find.text('Offer rematch'), findsOneWidget);
    expect(find.text('Review game'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an aborted game says so, unrated', (tester) async {
    final api = await _pump(tester);
    api.setGame(
      api.copy(
        api.games['g1']!,
        status: GameStatus.aborted,
        termination: 'firstMoveTimeout',
      ),
    );
    api.hint('g1');
    await _settle(tester);
    expect(find.text('Game aborted'), findsOneWidget);
    expect(find.text('No first move in time · not rated'), findsOneWidget);
    expect(find.text('Offer rematch'), findsNothing);
    await unmount(tester);
  });

  testWidgets('a rejected move rolls back with a short message', (
    tester,
  ) async {
    final api = await _pump(tester, moves: ['e2e4', 'e7e5']);
    api.failures['makeMove'] = [const OnlineRejected('STALE')];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnlineGameScreen)),
    );
    await container
        .read(onlineGameProvider('g1').notifier)
        .move(Move.parse('g1f3')!);
    await _settle(tester);
    expect(find.text('Nf3'), findsNothing);
    expect(
      find.text('The game moved on. The board is back in sync.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('Dismiss'), findsNothing);
    await unmount(tester);
  });
}
