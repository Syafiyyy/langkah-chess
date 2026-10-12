import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';
import 'board_theme.dart';
import 'piece_choice.dart';

export '../storage/storage_providers.dart' show kvStoreProvider;

/// The player's board look: theme + piece set.
class BoardPrefs {
  const BoardPrefs({
    this.theme = BoardTheme.defaultTheme,
    this.pieces = PieceChoice.defaultChoice,
  });

  final BoardTheme theme;
  final PieceChoice pieces;

  BoardPrefs copyWith({BoardTheme? theme, PieceChoice? pieces}) =>
      BoardPrefs(theme: theme ?? this.theme, pieces: pieces ?? this.pieces);
}

/// Board preferences for every board in the app. Starts with the defaults
/// and switches to the saved choice as soon as it is read.
final boardPrefsProvider = NotifierProvider<BoardPrefsNotifier, BoardPrefs>(
  BoardPrefsNotifier.new,
);

class BoardPrefsNotifier extends Notifier<BoardPrefs> {
  static const _themeKey = 'board.theme';
  static const _piecesKey = 'board.pieces';

  /// Set once the player changes something, so a slow load can't undo it.
  bool _changed = false;

  @override
  BoardPrefs build() {
    unawaited(_load());
    return const BoardPrefs();
  }

  Future<void> _load() async {
    try {
      final kv = ref.read(kvStoreProvider);
      final theme = await kv.get(_themeKey);
      final pieces = await kv.get(_piecesKey);
      if (!ref.mounted || _changed) return;
      state = BoardPrefs(
        theme: BoardTheme.byId(theme),
        pieces: PieceChoice.byName(pieces),
      );
    } on Object catch (e) {
      debugPrint('[settings] load board prefs: $e');
    }
  }

  void setTheme(BoardTheme theme) {
    _changed = true;
    state = state.copyWith(theme: theme);
    _save(_themeKey, theme.id);
  }

  void setPieces(PieceChoice pieces) {
    _changed = true;
    state = state.copyWith(pieces: pieces);
    _save(_piecesKey, pieces.name);
  }

  void _save(String key, String value) => unawaited(
    ref
        .read(kvStoreProvider)
        .set(key, value)
        .catchError((Object e) => debugPrint('[settings] save $key: $e')),
  );
}
