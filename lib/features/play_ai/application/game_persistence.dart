import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/domain/finished_game.dart';
import '../domain/game_state.dart';
import 'play_ai_providers.dart';

/// Stores an offline game: autosave while it runs, history exactly once
/// when it ends (called only from GameController.onFinished). Storage
/// failures are logged, never thrown: they must not break a game.
class GamePersistence {
  GamePersistence(this._ref);

  final Ref _ref;
  Future<void>? _saving;

  /// Completes once the last finished game is in history.
  Future<void> whenSaved() => _saving ?? Future.value();

  void autosave(GameState game, Duration now) {
    if (game.isOver) return;
    unawaited(
      _ref
          .read(playAiStoreProvider)
          .saveGame(game, now)
          .then((_) => _refreshResumeBanner())
          // A failed autosave only loses resume-after-kill; never the game.
          .catchError((Object e) => debugPrint('[play_ai] autosave: $e')),
    );
  }

  void finished(GameState game) {
    final store = _ref.read(playAiStoreProvider);
    final history = _ref.read(historyRepositoryProvider);
    unawaited(
      _saving = history
          .save(FinishedGame.fromState(game))
          .then((_) => store.clearGame())
          .then((_) => _refreshResumeBanner())
          .catchError((Object e) => debugPrint('[play_ai] save failed: $e')),
    );
  }

  /// Forgets the autosaved game (abandon). Nothing goes to history.
  Future<void> clear() async {
    try {
      await _ref.read(playAiStoreProvider).clearGame();
    } on Object catch (e) {
      debugPrint('[play_ai] clear autosave: $e');
    }
    _refreshResumeBanner();
  }

  void _refreshResumeBanner() {
    if (_ref.mounted) _ref.invalidate(savedGameProvider);
  }
}
