import 'package:go_router/go_router.dart';

import '../features/auth/presentation/online_gate.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/history/presentation/replay_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/online/presentation/online_home_screen.dart';
import '../features/play_ai/presentation/game_screen.dart';
import '../features/review/presentation/review_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// App routes.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/play', builder: (context, state) => const GameScreen()),
    GoRoute(
      path: '/online',
      builder: (context, state) =>
          const OnlineGate(child: OnlineHomeScreen()),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const OnlineGate(child: ProfileScreen()),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/review/:id',
      builder: (context, state) =>
          ReviewScreen(gameId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              ReplayScreen(gameId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
