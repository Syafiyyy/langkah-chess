import 'package:go_router/go_router.dart';

import '../../auth/presentation/online_gate.dart';
import '../../play_ai/domain/time_control.dart';
import 'invite_screen.dart';
import 'join_code_screen.dart';
import 'online_game_screen.dart';
import 'online_home_screen.dart';
import 'searching_screen.dart';

/// `/online` and its pages, all behind [OnlineGate]. Nested, so Back from a
/// game or invite returns to the online home.
final GoRoute onlineRoute = GoRoute(
  path: '/online',
  builder: (context, state) => const OnlineGate(child: OnlineHomeScreen()),
  routes: [
    GoRoute(
      path: 'invite',
      builder: (context, state) => OnlineGate(
        child: InviteScreen(timeControl: _tc(state)),
      ),
    ),
    GoRoute(
      path: 'join',
      builder: (context, state) => OnlineGate(
        child: JoinCodeScreen(initialCode: state.uri.queryParameters['code']),
      ),
    ),
    GoRoute(
      path: 'search',
      builder: (context, state) => OnlineGate(
        child: SearchingScreen(timeControl: _tc(state)),
      ),
    ),
    GoRoute(
      path: 'game/:id',
      builder: (context, state) => OnlineGate(
        child: OnlineGameScreen(gameId: state.pathParameters['id']!),
      ),
    ),
  ],
);

TimeControl _tc(GoRouterState state) {
  try {
    return TimeControl.parse(state.uri.queryParameters['tc'] ?? '');
  } on FormatException {
    return const TimeControl.minutes(5, 0);
  }
}
