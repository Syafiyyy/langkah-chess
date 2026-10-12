import '../../../core/storage/kv_store.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
import 'saved_game_codec.dart';

/// Persists the last new-game choice and the autosaved in-progress game.
class PlayAiStore {
  PlayAiStore(this._kv);

  final KvStore _kv;

  static const _setupKey = 'play_ai.last_setup';
  static const _gameKey = 'play_ai.saved_game';

  Future<GameSetup> lastSetup() async {
    final text = await _kv.get(_setupKey);
    return (text == null ? null : GameSetup.decode(text)) ?? GameSetup.defaults;
  }

  Future<void> saveSetup(GameSetup setup) => _kv.set(_setupKey, setup.encode());

  /// The autosaved game, with its clock running from [now]; null if none.
  Future<GameState?> loadGame(Duration now) async {
    final json = await _kv.get(_gameKey);
    return json == null ? null : decodeSavedGame(json, now);
  }

  Future<void> saveGame(GameState state, Duration now) =>
      _kv.set(_gameKey, encodeSavedGame(state, now));

  Future<void> clearGame() => _kv.remove(_gameKey);
}
