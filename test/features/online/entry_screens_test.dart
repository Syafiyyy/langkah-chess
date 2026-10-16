import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/online/data/online_api.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/online/presentation/invite_screen.dart';
import 'package:skak/features/online/presentation/join_code_screen.dart';
import 'package:skak/features/online/presentation/searching_screen.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

import 'fake_online_api.dart';
import 'online_harness.dart';

const _tc = TimeControl.minutes(5, 0);

void main() {
  group('invite', () {
    testWidgets('shows the code and opens the game when the friend joins', (
      tester,
    ) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const InviteScreen(timeControl: _tc));
      await tester.pump();
      expect(api.calls, contains('createInvite 5+0'));
      expect(find.text('RVMP92'), findsOneWidget);
      expect(find.text('skak://join/RVMP92'), findsOneWidget);
      expect(find.text('Share invite'), findsOneWidget);
      expect(tester.takeException(), isNull);

      api.setGame(api.copy(api.games['inv']!, status: GameStatus.active));
      api.hint('inv');
      await tester.pumpAndSettle();
      expect(find.text('GAME inv'), findsOneWidget);
    });

    testWidgets('a missed hint is caught by the poll', (tester) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const InviteScreen(timeControl: _tc));
      await tester.pump();
      api.setGame(api.copy(api.games['inv']!, status: GameStatus.active));
      await tester.pump(InviteScreen.pollEvery);
      await tester.pumpAndSettle();
      expect(find.text('GAME inv'), findsOneWidget);
    });

    testWidgets('an expired invite says so and offers a new one', (
      tester,
    ) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const InviteScreen(timeControl: _tc));
      await tester.pump();
      api.setGame(
        api.copy(
          api.games['inv']!,
          status: GameStatus.aborted,
          termination: 'expired',
        ),
      );
      api.hint('inv');
      await tester.pumpAndSettle();
      expect(find.text('This invite expired'), findsOneWidget);
      expect(find.text('Nobody joined within 24 hours'), findsOneWidget);

      api.games.remove('inv');
      await tester.tap(find.text('Create new invite'));
      await tester.pumpAndSettle();
      expect(api.count('createInvite'), 2);
      expect(find.text('RVMP92'), findsOneWidget);
    });

    testWidgets('cancel aborts the invite and goes back', (tester) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const InviteScreen(timeControl: _tc));
      await tester.pump();
      await tester.tap(find.text('Cancel invite'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('act abort'));
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('offline: says so with a retry', (tester) async {
      final api = FakeOnlineApi()
        ..failures['rpc'] = [const OnlineUnavailable()];
      await pumpOnlinePage(tester, api, const InviteScreen(timeControl: _tc));
      await tester.pump();
      expect(find.textContaining("wasn't created"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(find.text('RVMP92'), findsOneWidget);
    });
  });

  group('join', () {
    testWidgets('upper-cases, drops other characters, max 6', (tester) async {
      await pumpOnlinePage(tester, FakeOnlineApi(), const JoinCodeScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab-c 2 34xyz');
      await tester.pump();
      expect(find.text('ABC234'), findsOneWidget);
    });

    testWidgets('joins and opens the game', (tester) async {
      final api = FakeOnlineApi()..addGame();
      await pumpOnlinePage(tester, api, const JoinCodeScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc234');
      await tester.tap(find.text('Join game'));
      await tester.pumpAndSettle();
      expect(api.calls, ['joinInvite ABC234']);
      expect(find.text('GAME g1'), findsOneWidget);
    });

    testWidgets('explains a wrong code', (tester) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const JoinCodeScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ZZZZZZ');
      await tester.tap(find.text('Join game'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No game has that code'), findsOneWidget);
    });

    testWidgets('a short code is checked before asking the server', (
      tester,
    ) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(tester, api, const JoinCodeScreen());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABC');
      await tester.tap(find.text('Join game'));
      await tester.pumpAndSettle();
      expect(find.text('Codes have 6 characters'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('a link code joins right away', (tester) async {
      final api = FakeOnlineApi()..addGame();
      await pumpOnlinePage(
        tester,
        api,
        const JoinCodeScreen(initialCode: 'abc234'),
      );
      await tester.pumpAndSettle();
      expect(api.calls, ['joinInvite ABC234']);
      expect(find.text('GAME g1'), findsOneWidget);
    });
  });

  group('quick match', () {
    testWidgets('queues, re-asks every 30 s, and opens the game once paired', (
      tester,
    ) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(
        tester,
        api,
        const SearchingScreen(timeControl: _tc),
      );
      await tester.pump();
      expect(api.count('joinQueue'), 1);
      expect(find.text('5+0'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0:03'), findsOneWidget);
      await tester.pump(const Duration(seconds: 27));
      expect(api.count('joinQueue'), 2);

      api.queuedGame = api.addGame();
      api.hintMine();
      await tester.pumpAndSettle();
      expect(api.count('joinQueue'), 3);
      expect(find.text('GAME g1'), findsOneWidget);
      // Paired: no leave_queue (the queue entry is already gone).
      expect(api.calls, isNot(contains('leaveQueue')));
    });

    testWidgets('stop searching leaves the queue', (tester) async {
      final api = FakeOnlineApi();
      await pumpOnlinePage(
        tester,
        api,
        const SearchingScreen(timeControl: _tc),
      );
      await tester.pump();
      await tester.tap(find.text('Stop searching'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('leaveQueue'));
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('network trouble shows Reconnecting and keeps trying', (
      tester,
    ) async {
      final api = FakeOnlineApi()
        ..failures['rpc'] = [const OnlineUnavailable()];
      await pumpOnlinePage(
        tester,
        api,
        const SearchingScreen(timeControl: _tc),
      );
      await tester.pump();
      expect(find.text('Reconnecting…'), findsOneWidget);
      await tester.pump(SearchingScreen.heartbeat);
      expect(find.text('Reconnecting…'), findsNothing);
      // Leave the screen so its timers stop.
      await tester.tap(find.text('Stop searching'));
      await tester.pumpAndSettle();
    });
  });
}
