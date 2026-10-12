import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/board/board_prefs.dart';
import 'package:skak/core/board/board_theme.dart';
import 'package:skak/core/board/piece_choice.dart';
import 'package:skak/core/storage/kv_store.dart';

import '../../features/play_ai/presentation/game_test_harness.dart';

void main() {
  ProviderContainer container(KvStore kv) => ProviderContainer.test(
    overrides: [kvStoreProvider.overrideWithValue(kv)],
  );

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('defaults to songket and cburnett', () async {
    final c = container(MemoryKvStore());
    expect(c.read(boardPrefsProvider).theme, BoardTheme.songket);
    expect(c.read(boardPrefsProvider).pieces, PieceChoice.cburnett);
  });

  test('choices are saved and loaded in a new session', () async {
    final kv = MemoryKvStore();
    final first = container(kv);
    first.read(boardPrefsProvider.notifier)
      ..setTheme(BoardTheme.graphite)
      ..setPieces(PieceChoice.merida);
    await settle();
    expect(first.read(boardPrefsProvider).theme, BoardTheme.graphite);

    final second = container(kv);
    second.read(boardPrefsProvider);
    await settle();
    expect(second.read(boardPrefsProvider).theme, BoardTheme.graphite);
    expect(second.read(boardPrefsProvider).pieces, PieceChoice.merida);
  });

  test('unknown stored values fall back to the defaults', () async {
    final kv = MemoryKvStore()
      ..values['board.theme'] = 'neon'
      ..values['board.pieces'] = 'wooden';
    final c = container(kv);
    c.read(boardPrefsProvider);
    await settle();
    expect(c.read(boardPrefsProvider).theme, BoardTheme.songket);
    expect(c.read(boardPrefsProvider).pieces, PieceChoice.cburnett);
  });
}
