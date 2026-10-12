import '../domain/game_state.dart';

/// What the game screen renders.
class PlayAiView {
  const PlayAiView({
    required this.game,
    this.botThinking = false,
    this.viewedPly,
    this.engineFailed = false,
  });

  final GameState game;

  /// The engine is searching for the bot's move.
  final bool botThinking;

  /// Index into `game.positions` being browsed read-only; null = live board.
  final int? viewedPly;

  /// The last bot search failed; the screen offers a retry.
  final bool engineFailed;

  bool get isBrowsing => viewedPly != null;

  bool get canTakeback =>
      !game.isOver &&
      !botThinking &&
      game.isPlayerTurn &&
      game.moves.length >=
          (game.playerSide == game.initialPosition.turn ? 2 : 3);

  PlayAiView copyWith({
    GameState? game,
    bool? botThinking,
    int? Function()? viewedPly,
    bool? engineFailed,
  }) => PlayAiView(
    game: game ?? this.game,
    botThinking: botThinking ?? this.botThinking,
    viewedPly: viewedPly == null ? this.viewedPly : viewedPly(),
    engineFailed: engineFailed ?? this.engineFailed,
  );
}
