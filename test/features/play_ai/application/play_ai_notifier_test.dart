import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/engine/engine_provider.dart';
import 'package:langkah/core/engine/engine_service.dart';
import 'package:langkah/core/storage/app_database.dart';
import 'package:langkah/features/play_ai/application/play_ai_notifier.dart';
import 'package:langkah/features/play_ai/application/play_ai_providers.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_result.dart';
import 'package:langkah/features/play_ai/domain/game_setup.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/engine/fake_uci_engine.dart';
import '../domain/fake_time_source.dart';
import 'bot_engine_fake.dart';

GameSetup _setup({
  ColorChoice color = ColorChoice.white,
  int level = 1,
  TimeControl tc = const TimeControl.minutes(3, 2),
}) => GameSetup(level: BotLevel.of(level), color: color, timeControl: tc);

void main() {
  late Database db;
  late FakeTimeSource time;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    time = FakeTimeSource();
  });

  tearDown(() => db.close());

  ProviderContainer container(FakeUciEngine engine) => ProviderContainer.test(
    overrides: [
      engineServiceProvider.overrideWithValue(
        EngineService(() async => engine),
      ),
      timeSourceProvider.overrideWithValue(time),
      appDatabaseProvider.overrideWithValue(db),
    ],
  );

  /// Lets engine replies and storage writes run.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<int> historyCount(ProviderContainer c) async =>
      (await c.read(historyRepositoryProvider).list()).length;

  test('the bot replies to the player\'s move', () async {
    final c = container(botEngine(script: ['e7e5']));
    final notifier = c.read(playAiProvider.notifier);

    await notifier.start(_setup());
    notifier.move(Move.parse('e2e4')!);
    expect(c.read(playAiProvider)!.botThinking, isTrue);
    await settle();

    final view = c.read(playAiProvider)!;
    expect(view.game.moves.map((m) => m.uci), ['e2e4', 'e7e5']);
    expect(view.botThinking, isFalse);
  });

  test('as black, the bot moves first with the chosen level', () async {
    final engine = botEngine(script: ['d2d4']);
    final c = container(engine);

    await c
        .read(playAiProvider.notifier)
        .start(_setup(color: ColorChoice.black));
    await settle();

    expect(c.read(playAiProvider)!.game.moves.single.uci, 'd2d4');
    final firstGo = engine.commands.indexWhere((x) => x.startsWith('go'));
    final skill = engine.commands.indexOf('setoption name Skill Level value 0');
    expect(skill, isNonNegative);
    expect(skill, lessThan(firstGo));
    expect(engine.commands[firstGo], 'go depth 1 movetime 100');
  });

  test('takeback cancels the search and drops its late move', () async {
    final engine = botEngine(holdUntilStop: true);
    final c = container(engine);
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());
    notifier.move(Move.parse('e2e4')!);
    await settle();
    expect(c.read(playAiProvider)!.botThinking, isTrue);

    await notifier.takeback();
    await settle();

    final view = c.read(playAiProvider)!;
    expect(view.game.moves, isEmpty);
    expect(view.botThinking, isFalse);
    expect(engine.commands, contains('stop'));
  });

  test('a stale reply is dropped even when it is still legal', () async {
    // Leave the screen while the bot thinks, then come back: the first
    // search is stopped and answers e7e5, which is legal but stale.
    final c = container(
      botEngine(script: ['e7e5', 'c7c5'], holdFirstOnly: true),
    );
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());
    notifier.move(Move.parse('e2e4')!);
    await settle();

    notifier.suspend();
    await settle();
    await notifier.resumeSaved();
    await settle();

    final moves = c.read(playAiProvider)!.game.moves.map((m) => m.uci);
    expect(moves, ['e2e4', 'c7c5']);
  });

  test('a finished game is saved to history exactly once', () async {
    final c = container(botEngine(script: ['e7e5', 'd8h4']));
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());

    notifier.move(Move.parse('f2f3')!);
    await settle();
    notifier.move(Move.parse('g2g4')!);
    await settle();

    final view = c.read(playAiProvider)!;
    expect(view.game.result?.termination, Termination.checkmate);
    notifier.resign(); // ignored: already over
    await notifier.takeback();
    await settle();
    expect(await historyCount(c), 1);
    expect(await c.read(playAiStoreProvider).loadGame(time.now()), isNull);
  });

  test('resigning saves the loss once', () async {
    final c = container(botEngine());
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());
    notifier
      ..resign()
      ..resign();
    await settle();
    final games = await c.read(historyRepositoryProvider).list();
    expect(games.single.result.termination, Termination.resignation);
    expect(games.single.playerResult.name, 'loss');
  });

  test('the bot\'s flag falls while it is thinking', () async {
    final c = container(botEngine(holdUntilStop: true));
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());
    notifier.move(Move.parse('e2e4')!); // starts the bot's clock
    await settle();

    time.advance(const Duration(seconds: 181));
    notifier.checkFlag();
    await settle();

    final view = c.read(playAiProvider)!;
    expect(view.game.result?.termination, Termination.timeout);
    expect(view.game.result?.outcome, Outcome.whiteWins);
    expect(view.game.moves, hasLength(1)); // late bot move ignored
    expect(view.botThinking, isFalse);
    expect(await historyCount(c), 1);
  });

  test('an in-progress game is autosaved and can be resumed', () async {
    final first = container(botEngine(script: ['c7c5']));
    await first.read(playAiProvider.notifier).start(_setup(level: 4));
    first.read(playAiProvider.notifier).move(Move.parse('e2e4')!);
    await settle();
    first.dispose();

    final second = container(botEngine());
    expect(await second.read(savedGameProvider.future), isTrue);
    final resumed = await second.read(playAiProvider.notifier).resumeSaved();
    expect(resumed, isTrue);
    final view = second.read(playAiProvider)!;
    expect(view.game.moves.map((m) => m.uci), ['e2e4', 'c7c5']);
    expect(view.game.level.number, 4);
  });

  test('the last setup is remembered', () async {
    final c = container(botEngine());
    await c
        .read(playAiProvider.notifier)
        .start(_setup(level: 6, color: ColorChoice.random));
    final setup = await c.read(playAiStoreProvider).lastSetup();
    expect(setup.level.number, 6);
    expect(setup.color, ColorChoice.random);
  });

  test('browsing a past position never changes the game', () async {
    final c = container(botEngine(script: ['e7e5']));
    final notifier = c.read(playAiProvider.notifier);
    await notifier.start(_setup());
    notifier.move(Move.parse('e2e4')!);
    await settle();

    notifier.viewPly(1);
    expect(c.read(playAiProvider)!.viewedPly, 1);
    notifier.move(Move.parse('g1f3')!); // ignored while browsing
    expect(c.read(playAiProvider)!.game.moves, hasLength(2));
    notifier.viewPly(null);
    expect(c.read(playAiProvider)!.viewedPly, isNull);
  });
}
