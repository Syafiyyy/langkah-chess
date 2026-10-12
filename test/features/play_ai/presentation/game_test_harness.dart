import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/core/engine/engine_provider.dart';
import 'package:langkah/core/engine/engine_service.dart';
import 'package:langkah/core/storage/kv_store.dart';
import 'package:langkah/features/history/data/history_repository.dart';
import 'package:langkah/features/history/domain/finished_game.dart';
import 'package:langkah/features/play_ai/application/play_ai_providers.dart';
import 'package:langkah/features/play_ai/data/play_ai_store.dart';

import '../../../core/engine/fake_uci_engine.dart';
import '../domain/fake_time_source.dart';

/// In-memory key-value store.
class MemoryKvStore implements KvStore {
  final Map<String, String> values = {};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// In-memory history that records every save call.
class MemoryHistory implements HistoryRepository {
  final List<FinishedGame> saved = [];

  @override
  Future<void> save(FinishedGame game) async => saved.add(game);

  @override
  Future<List<FinishedGame>> list({
    HistoryFilter filter = HistoryFilter.all,
  }) async => saved.reversed.toList();

  @override
  Future<FinishedGame?> byId(String id) async =>
      saved.where((g) => g.id == id).firstOrNull;
}

/// Everything a widget test needs to host play_ai screens without native
/// code: fake engine, fake time, in-memory storage.
class GameTestHarness {
  GameTestHarness(this.engine);

  final FakeUciEngine engine;
  final time = FakeTimeSource();
  final kv = MemoryKvStore();
  final history = MemoryHistory();
  final pauses = <Duration>[];

  late final List<Override> overrides = [
    engineServiceProvider.overrideWithValue(EngineService(() async => engine)),
    timeSourceProvider.overrideWithValue(time),
    playAiStoreProvider.overrideWithValue(PlayAiStore(kv)),
    kvStoreProvider.overrideWithValue(kv),
    historyRepositoryProvider.overrideWithValue(history),
    randomProvider.overrideWithValue(Random(1)),
    // Thinking pauses are recorded, not waited for.
    pauseProvider.overrideWithValue((d) async => pauses.add(d)),
  ];

  Widget wrap(Widget child) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );
}
