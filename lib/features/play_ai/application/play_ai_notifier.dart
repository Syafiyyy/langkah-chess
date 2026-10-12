import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_provider.dart';
import '../../history/domain/finished_game.dart';
import '../domain/bot_level.dart';
import '../domain/game_controller.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
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
    final state = GameState.start(
      id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
      level: setup.level,
      timeControl: setup.timeControl,
      playerSide: setup.resolveSide(Random()),
      startedAt: DateTime.now(),
    );
    unawaited(ref.read(playAiStoreProvider).saveSetup(setup));
    await _load(state);
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
    if (controller == null || controller.state.isOver) return;
    controller.pause();
    _publish();
    _autosave();
  }

  void appResumed() {
    final controller = _controller;
    if (controller == null || controller.state.isOver) return;
    controller.resume();
    _publish();
  }

  /// The game screen closed: stop the bot, freeze the clock, save.
  void suspend() {
    final controller = _controller;
    if (controller == null || controller.state.isOver) return;
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
      onFinished: _onFinished,
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
    final level = game.level;
    _publish(botThinking: true, engineFailed: false);
    final clock = game.clock;
    final thinkTime = botThinkTime(
      level,
      remaining: clock?.remaining(game.botSide, _now),
      increment: game.timeControl.increment,
    );
    try {
      final engine = ref.read(engineServiceProvider);
      // Set the level before every search: the engine restarts with default
      // options after it was disposed (app detach, hot reload).
      await engine.setOptions(level.engineOptions);
      if (!_isCurrent(generation, controller)) return;
      final result = await engine.bestMove(
        game.position.fen,
        moveTime: thinkTime,
        depth: level.depth,
      );
      if (!_isCurrent(generation, controller)) return;
      final uci = result.bestMove;
      final move = uci == null ? null : Move.parse(uci);
      if (move == null || !controller.play(move)) {
        // The flag fell first, or the engine had no move: nothing to play.
        _publish(botThinking: false, engineFailed: !controller.state.isOver);
        return;
      }
      _publish(botThinking: false);
      _autosave();
    } on Object catch (e) {
      debugPrint('[play_ai] bot search failed: $e');
      if (!_isCurrent(generation, controller)) return;
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
    if (game == null || game.isOver) return;
    unawaited(
      ref
          .read(playAiStoreProvider)
          .saveGame(game, _now)
          .then((_) => _refreshResumeBanner()),
    );
  }

  void _onFinished(GameState finished) {
    _flagTimer?.cancel();
    final store = ref.read(playAiStoreProvider);
    final history = ref.read(historyRepositoryProvider);
    unawaited(
      history
          .save(FinishedGame.fromState(finished))
          .then((_) => store.clearGame())
          .then((_) => _refreshResumeBanner())
          .catchError((Object e) => debugPrint('[play_ai] save failed: $e')),
    );
  }

  void _refreshResumeBanner() {
    if (ref.mounted) ref.invalidate(savedGameProvider);
  }
}
