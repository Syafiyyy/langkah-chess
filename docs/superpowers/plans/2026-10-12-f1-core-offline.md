# F1 Core Offline Implementation Plan

> Executed inline (native) in the F1 session. Steps use checkboxes for tracking.

**Goal:** A complete, correct offline game against Stockfish: levels, clock, all result rules, takeback, history with PGN, resume after kill.

**Architecture:** Pure-Dart domain (`features/play_ai/domain`) owns rules, clock and results. A Riverpod notifier (`application`) wraps `GameController`, drives `EngineService`, autosaves and saves history once. Widgets render state and dispatch actions only.

**Tech stack:** dartchess 0.14, chessground 10.3, multistockfish 0.6.1, flutter_riverpod 3.4, go_router 18, sqflite 2.4 (+ sqflite_common_ffi for tests), share_plus.

**Spec:** `docs/prompts/F1.md`

## Global constraints
- Stack fixed by ADRs. No codegen (ADR-0006). dartchess is the only rules source.
- Domain files import no Flutter.
- Files under ~300 lines; one widget/screen per file.
- `flutter analyze` + `flutter test` green before every commit.
- Engine access only through `EngineService` (stdout listened once, serialised commands).

## Review focus (failure modes no obvious test hits)
1. Bot reply arrives after resign / takeback / leaving the screen → must be discarded (generation check). Test in notifier.
2. Bot's flag falls while it is still thinking → game ends by timeout, the late move is ignored. Test in notifier.
3. App killed mid-game, relaunched → resumed game has same moves, clocks and colour; autosave cleared when the game ends. Test autosave round-trip.
4. Player black + bot first move → uses the chosen level's options and movetime. Test in notifier (fake engine records `setoption` before first `go`).
5. Promotion via picker and capture-promotion produce correct SAN/UCI. Test in controller + widget.

---

### Task 1: Domain value types (TDD)
Files: `domain/time_control.dart`, `domain/bot_level.dart`, `domain/game_setup.dart`; tests under `test/features/play_ai/domain/`.
- `TimeControl(initial, increment)`, `TimeControl.unlimited`, presets 3+2, 5+0, 10+0, 15+10, 30+0; `label`.
- `BotLevel` table (8 levels): engine options map, `depth?`, `moveTime`, `approxRating`. Low levels: `UCI_LimitStrength false` + `Skill Level` + depth cap. High levels: `UCI_LimitStrength true` + `UCI_Elo`. Level 8: full strength.
- `botThinkTime(level, remaining?, increment)` = min(level time, remaining/30 + increment/2), floor 50 ms.
- Verify real option ranges on the emulator (`uci` → `option` lines) before freezing the table.

### Task 2: Clock (TDD)
Files: `domain/time_source.dart` (`TimeSource { Duration now() }`, `MonotonicTimeSource`), `domain/chess_clock.dart` (immutable `ChessClock`).
- `start(side, now)`, `moved(now)` (deduct elapsed, add increment, switch), `pause(now)`, `resume(now)`, `remaining(side, now)`, `flagged(now) → Side?`, `stop(now)`.
- Tests with fake time: increment, pause/resume, flag, unlimited never flags.

### Task 3: Results + GameState + GameController (TDD)
Files: `domain/game_result.dart`, `domain/game_state.dart`, `domain/game_controller.dart`.
- `Termination` enum; `GameResult(outcome, termination)`; `resultOf(position, repetitions)`; `timeoutResult(position, flaggedSide)`.
- `positionKey(position)` = first 4 FEN fields.
- `GameState`: setup, playerSide, positions, moves (`MoveRecord(uci, san)`), clock, result, startedAt, endedAt.
- `GameController(setup, playerSide, timeSource, onFinished)`: `play(Move)`, `takeback()`, `resign()`, `checkFlag()`, `pause()`, `resume()`, `restore(...)`. Clock starts after White's first move. `onFinished` fires exactly once.
- Tests: every result type, timeout vs insufficient material both ways, repetition (incl. ep/castling key), 75-move, takeback, promotion, onFinished once.

### Task 4: PGN + history repository + autosave (TDD)
Files: `domain/game_pgn.dart`, `features/history/domain/finished_game.dart`, `features/history/data/history_repository.dart`, `core/storage/app_database.dart`, `core/storage/kv_store.dart`, `features/play_ai/data/saved_game_codec.dart`.
- sqflite DB: `games` table + `kv` table (last setup, autosave). Repository: `save`, `list(filter)`, `byId`.
- Tests: PGN round-trip (parse with dartchess → same SAN + result), repository with sqflite_common_ffi in-memory, autosave codec round-trip.

### Task 5: EngineService.setOptions + depth (TDD)
- `setOptions(Map<String, String>)`: serialised, stops current search, sends `setoption`, waits `readyok`. `bestMove(fen, moveTime, depth?)`. Public `stop()`.
- Tests with FakeUciEngine.

### Task 6: Application notifier (TDD)
Files: `application/play_ai_notifier.dart`, `application/play_ai_providers.dart`, `application/play_ai_view.dart`.
- Starts game (random colour resolved), warms engine, sets level options, asks bot when it's the bot's turn, discards stale replies, schedules flag timer, autosaves after each move, clears autosave + saves history once at end, pause/resume on lifecycle, viewPly browsing.
- Tests with fake engine + in-memory repos: bot replies, black-player first move uses level, takeback cancels search, end saves once, timeout during thinking.

### Task 7: Screens
Files: home, new game sheet, game screen (+ board, clock bar, move list, controls, game-over sheet), history list, replay screen; router. Delete smoke screen.
- Widget tests: game screen builds; promotion picker flow; game-over sheet appears; 360 dp no overflow.

### Task 8: Verify + docs
- Emulator runs (low + high level, 3 games), measurements, STATE.md, Gate 1 checklist, commits, push, CI green.
