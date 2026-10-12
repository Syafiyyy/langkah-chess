import 'package:go_router/go_router.dart';

import '../features/play_ai/presentation/board_smoke_screen.dart';

/// App routes. F0 has a single smoke-test screen.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const BoardSmokeScreen()),
  ],
);
