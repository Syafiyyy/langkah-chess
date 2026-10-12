import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_service.dart';
import 'uci_engine.dart';

/// The one EngineService for the whole app. It is kept alive and is disposed
/// together with the ProviderScope.
final engineServiceProvider = Provider<EngineService>((ref) {
  final service = EngineService(StockfishUciEngine.start);
  ref.onDispose(service.dispose);
  return service;
});
