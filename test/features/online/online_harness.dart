import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skak/app/theme/app_theme.dart';
import 'package:skak/features/online/application/online_providers.dart';

import 'fake_online_api.dart';

/// Pumps [page] at `/page` under `/` (so pop works) with a stub game route
/// that shows "GAME id".
Future<GoRouter> pumpOnlinePage(
  WidgetTester tester,
  FakeOnlineApi api,
  Widget page, {
  List<Override> overrides = const [],
  Size size = const Size(360, 640),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/page',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('ROOT')),
        routes: [GoRoute(path: 'page', builder: (_, _) => page)],
      ),
      GoRoute(
        path: '/online/game/:id',
        builder: (_, s) => Text('GAME ${s.pathParameters['id']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [onlineApiProvider.overrideWithValue(api), ...overrides],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
        // Reduced motion: no looping animations (pending timers in tests).
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  return router;
}

/// Removes the page so its timers stop before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}
