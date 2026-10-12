import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_provider.dart';
import '../domain/game_controller.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
import 'bot_mover.dart';
import 'game_persistence.dart';
import 'play_ai_providers.dart';
import 'play_ai_view.dart';

/// The current offline game, or null when none is loaded.
final playAiProvider = NotifierProvider<PlayAiNotifier, PlayAiView?>(
  PlayAiNotifier.new,
);

/// Runs one offline game: wraps [GameController], asks the engine for bot
/// moves, autosaves, and saves the finished game to history (once, from the
/// controller's onFinished).
///
/// Every bot search gets a generation number. Anything that changes the game
/// under a running search (takeback, resign, flag, leaving) bumps the
/// generation and stops the engine, so a late reply is ignored.
class PlayAiNotifier extends Notifier<PlayAiView?> {
  GameController? _controller;
  BotMover? _bot;
  late final GamePersistence _persistence = GamePersistence(ref);
  int _generation = 0;
  Timer? _flagTimer;

  @override
  PlayAiView? build() {
    ref.onDispose(() => _flagTimer?.cancel());
    return null;
  }

  Duration get _now => ref.read(timeSourceProvider).now();

  /// Starts a new game with [setup] and remembers the setup.
  Future<void> start(GameSetup setup) async {
    final random = ref.read(randomProvider);
    final state = GameState.start(
      id: '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}',
      level: setup.level,
      timeControl: setup.timeControl,
      playerSide: setup.resolveSide(random),
      startedAt: DateTime.now(),
      botSpeed: setup.botSpeed,
    );
    unawaited(
      ref
          .read(playAiStoreProvider)
          .saveSetup(setup)
          .catchError((Object e) => debugPrint('[play_ai] setup save: $e')),
    );
    await _load(state);
  }

  /// Completes once the last finished game is in history (for "Review").
  Future<void> whenSaved() => _persistence.whenSaved();

  /// Drops the unfinished game: stops the bot, forgets the game and its
  /// autosave. Nothing goes to history (an abandoned game is not a loss).
  Future<void> abandon() async {
    await _cancelSearch();
    _flagTimer?.cancel();
    _controller = null;
    _bot = null;
    if (!ref.mounted) return;
    state = null;
    await _persistence.clear();
  }

  /// Continues the in-memory game, or the autosaved one. False if neither.
  Future<bool> resumeSaved() async {
    final current = _controller;
    if (current != null && !current.state.isOver) {
      current.resume();
      _publish();
      _askBotIfItsTurn();
      return true;
    }
    final saved = await ref.read(playAiStoreProvider).loadGame(_now);
    if (saved == null) return false;
    await _load(saved);
    return true;
  }

  /// The player's move from the board. Ignored unless it is the player's turn
  /// on the live board.
  void move(Move move) {
    final view = state;
    final controller = _controller;
    if (view == null || controller == null) return;
    if (view.isBrowsing || !controller.state.isPlayerTurn) return;
    if (!controller.play(move)) {
      _publish(); // the flag may have fallen
      return;
    }
    _afterChange();
  }

  /// Undoes back to the player's previous turn. Cancels a running search.
  Future<void> takeback() async {
    final controller = _controller;
    if (controller == null) return;
    await _cancelSearch();
    _publish(botThinking: false);
    if (controller.takeback()) _afterChange();
  }

  void resign() {
    final controller = _controller;
    if (controller == null || controller.state.isOver) return;
    unawaited(_cancelSearch());
    controller.resign();
    _publish(botThinking: false);
  }

  /// Ends the game if the running clock has run out.
  void checkFlag() {
    final controller = _controller;
    if (controller == null || !controller.checkFlag()) return;
    unawaited(_cancelSearch());
    _publish(botThinking: false);
  }

  /// Shows position [ply] read-only; null returns to the live board.
  void viewPly(int? ply) {
    final view = state;
    if (view == null) return;
    final last = view.game.positions.length - 1;
    final live = ply == null || ply >= last;
    state = view.copyWith(viewedPly: () => live ? null : max(0, ply));
  }

  /// Retries the bot's move after an engine failure.
  void retryBot() => _askBotIfItsTurn();

  /// App went to background: freeze the clock and save.
  void appPaused() {
    final controller = _controller;
    if (!ref.mounted || controller == null || controller.state.isOver) return;
    controller.pause();
    _publish();
    _autosave();
  }

  void appResumed() {
    final controller = _controller;
    if (!ref.mounted || controller == null || controller.state.isOver) return;
    controller.resume();
    _publish();
  }

  /// The game screen closed: stop the bot, freeze the clock, save.
  void suspend() {
    final controller = _controller;
    if (!ref.mounted || controller == null || controller.state.isOver) return;
    unawaited(_cancelSearch());
    controller.pause();
    _publish(botThinking: false);
    _autosave();
  }

  Future<void> _load(GameState game) async {
    await _cancelSearch();
    _controller = GameController(
      state: game,
      time: ref.read(timeSourceProvider),
      onFinished: (game) {
        _flagTimer?.cancel();
        _persistence.finished(game);
      },
    );
    _bot = BotMover(
      engine: ref.read(engineServiceProvider),
      level: game.level,
      random: ref.read(randomProvider),
      pause: ref.read(pauseProvider),
    );
    state = PlayAiView(game: game);
    _scheduleFlag();
    _autosave();
    // Warm the engine now so the first reply is fast.
    unawaited(
      ref.read(engineServiceProvider).newGame().catchError((Object _) {}),
    );
    _askBotIfItsTurn();
  }

  void _afterChange() {
    _publish();
    _autosave();
    _askBotIfItsTurn();
  }

  void _askBotIfItsTurn() {
    final controller = _controller;
    if (controller == null || !controller.state.isBotTurn) return;
    if (state?.botThinking ?? false) return;
    unawaited(_askBot(controller));
  }

  Future<void> _askBot(GameController controller) async {
    final generation = ++_generation;
    final game = controller.state;
    _publish(botThinking: true, engineFailed: false);
    bool current() => _isCurrent(generation, controller);
    try {
      final uci = await _bot!.play(
        game,
        remaining: game.clock?.remaining(game.botSide, _now),
        stillWanted: current,
      );
      if (!current()) return;
      final move = uci == null ? null : Move.parse(uci);
      if (move == null || !controller.play(move)) {
        // The flag fell first, or the engine had no move: nothing to play.
        _publish(botThinking: false, engineFailed: !controller.state.isOver);
        return;
      }
      _publish(botThinking: false);
      _autosave();
    } on Object catch (e) {
      debugPrint('[play_ai] bot move failed: $e');
      if (!current()) return;
      _publish(botThinking: false, engineFailed: true);
    }
  }

  bool _isCurrent(int generation, GameController controller) =>
      ref.mounted &&
      generation == _generation &&
      identical(controller, _controller);

  Future<void> _cancelSearch() async {
    _generation++;
    try {
      await ref.read(engineServiceProvider).stop();
    } on Object {
      // A dead engine has nothing to stop.
    }
  }

  void _publish({bool? botThinking, bool? engineFailed}) {
    final controller = _controller;
    if (controller == null || !ref.mounted) return;
    final view = state;
    state = view == null
        ? PlayAiView(game: controller.state)
        : view.copyWith(
            game: controller.state,
            botThinking: botThinking,
            engineFailed: engineFailed,
          );
    _scheduleFlag();
  }

  /// One timer at the exact moment the running side would flag.
  void _scheduleFlag() {
    _flagTimer?.cancel();
    final wait = _controller?.state.clock?.timeToFlag(_now);
    if (wait == null || _controller!.state.isOver) return;
    _flagTimer = Timer(wait + const Duration(milliseconds: 1), checkFlag);
  }

  void _autosave() {
    final game = _controller?.state;
    if (game != null) _persistence.autosave(game, _now);
  }
}
