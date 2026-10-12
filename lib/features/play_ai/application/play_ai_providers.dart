import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/kv_store.dart';
import '../../history/data/history_repository.dart';
import '../data/play_ai_store.dart';
import '../domain/time_source.dart';

/// The app database. Opened in `main()` and provided by an override.
final appDatabaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('Override appDatabaseProvider in main()'),
);

/// Randomness for bot moves, thinking pauses and colour choice (seeded in
/// tests).
final randomProvider = Provider<Random>((ref) => Random());

/// Waits for the bot's thinking pause (instant or controllable in tests).
final pauseProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

/// Monotonic time for game clocks.
final timeSourceProvider = Provider<TimeSource>((ref) => MonotonicTimeSource());

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => SqfliteHistoryRepository(ref.watch(appDatabaseProvider)),
);

final playAiStoreProvider = Provider<PlayAiStore>(
  (ref) => PlayAiStore(KvStore(ref.watch(appDatabaseProvider))),
);

/// Whether an unfinished game is saved (drives the "Resume game" banner).
final savedGameProvider = FutureProvider<bool>((ref) async {
  final now = ref.watch(timeSourceProvider).now();
  return await ref.watch(playAiStoreProvider).loadGame(now) != null;
});
