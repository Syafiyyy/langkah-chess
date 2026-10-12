import 'package:go_router/go_router.dart';

import '../features/history/presentation/history_screen.dart';
import '../features/history/presentation/replay_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/play_ai/presentation/game_screen.dart';
import '../features/review/presentation/review_screen.dart';

/// App routes.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/play', builder: (context, state) => const GameScreen()),
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
