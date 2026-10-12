import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine/engine_provider.dart';
import 'app_info.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget. Owns the engine lifecycle hooks (detach and hot reload).
class SkakApp extends ConsumerStatefulWidget {
  const SkakApp({super.key});

  @override
  ConsumerState<SkakApp> createState() => _SkakAppState();
}

class _SkakAppState extends ConsumerState<SkakApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onDetach: _disposeEngine);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Engine isolates break hot reload; drop the engine; it restarts lazily.
    if (kDebugMode) _disposeEngine();
  }

  void _disposeEngine() {
    ref.read(engineServiceProvider).dispose();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: kAppName,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
