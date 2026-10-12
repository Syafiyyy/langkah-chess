# STATE

_Single source of project state. Claude Code updates this at the end of every task._

## Current phase
F1 — Core offline: done in code (2026-10-12). Gate 1 waits for Adaam's check on a real phone. Next: Gate 1 hand check, then F1.5 — Game Review.

## Done
- 2026-10-12: Planning. v1 analysed, stack researched, blueprint independently reviewed, ADR-0001..0007 written, roadmap set. Kickoff docs created.
- 2026-10-12: F0 Foundation.
  - Tooling verified: dart-flutter plugin (Dart MCP), Context7 MCP, superpowers, gh (Syafiyyy). Skills karpathy-rules + frontend-design copied unchanged from DriveCover.
  - Flutter project created (`com.syafiyyy.langkah`, Android only, Kotlin DSL, one gradle setup). App name constant: `lib/app/app_info.dart` (+ Android manifest label).
  - Structure per ADR-0006: `app/` (app, router, theme tokens), `core/engine/`, `features/play_ai/presentation/`.
  - EngineService (`lib/core/engine/`): one lazy engine via a keep-alive Riverpod Provider, stdout listened once, output routed to the current request, `stop` before each new search, commands serialised, FEN validated with dartchess before it reaches the engine, dispose on app detach and on debug hot reload (engine restarts lazily).
  - Board smoke screen: chessground board from a dartchess `Position`, both sides move (legality from dartchess), "Engine move" and "New game" buttons.
  - Tests: 17 green (UCI parser, EngineService with a fake engine, board screen widget test). Strict lints, `flutter analyze` clean.
  - CI: `.github/workflows/ci.yml` (Flutter 3.47.7: pub get, analyze, test, debug split APK build). LICENSE GPL-3.0, README stub.
  - Verified on the emulator (Pixel 8a API 35, x86_64, release build): user moves and engine moves both work.

- 2026-10-12: F1 Core offline (plan: `docs/superpowers/plans/2026-10-12-f1-core-offline.md`).
  - Domain (`features/play_ai/domain`, pure Dart): `TimeControl`, `BotLevel` (8 levels), `botThinkTime`, `ChessClock`, `GameResult`/`Termination`/`positionKey`, `GameState`, `GameController`, `GameSetup`, `gamePgn`, `standardUci`.
  - Application: `PlayAiNotifier` (bot search per generation, flag timer, autosave, history saved once), providers (DB injected from `main()`).
  - Data: sqflite DB (`core/storage`: `games` + `kv` tables), `HistoryRepository`, `PlayAiStore` (last setup, autosaved game), saved-game codec.
  - EngineService: `setOptions` (waits for `readyok`), `bestMove(depth:)`, public `stop()`. F0 rules kept (stdout listened once, serialised commands).
  - Screens: home (resume banner), new game sheet, game screen (board, clocks, move list with read-only browsing, flip/takeback/resign), game-over sheet (new game / rematch with swapped colours / home), history (All/Wins/Losses/Draws), replay (step, flip, share/copy PGN). F0 smoke screen deleted.
  - Tests: 120 green. Domain: every result type, timeout vs insufficient material both ways, repetition by position key, takeback, clock with fake time, strength table, PGN round-trip. Repository on in-memory SQLite. Notifier with a scripted fake engine. Widget tests incl. promotion picker, game-over sheet, rematch, 360 dp width. Plus `integration_test/bot_games_test.dart` (on device, real Stockfish).
  - Verified on the emulator (Pixel 8a API 35, x86_64, release build): new game, bot reply, clock highlight, kill + "Resume game" with moves and clocks restored.

## Measurements (F1, emulator x86_64)
`integration_test/bot_games_test.dart`: a random-move player against real Stockfish, 3 full games in one session (debug build; the engine is native release code either way).
| Game | Result | Bot reply median / max |
|---|---|---|
| Level 1, unlimited, player black | bot won by checkmate, 39 plies | 23 ms / 411 ms (max = first reply, incl. engine start) |
| Level 8, unlimited, player white | bot won by checkmate, 40 plies | 1525 ms / 1628 ms (movetime 1500 ms) |
| Level 5, 3+2, player white | bot won by checkmate, 42 plies | 645 ms / 719 ms (movetime 600 ms) |
- No duplicate engine moves (each player move got exactly one bot reply). Never stuck thinking (15 s guard). Each game saved to history exactly once.
- Process RSS: 366 MB at start → 424 (after game 1: engine + NNUE loaded) → 437 → 441 MB. Levels off; no leak trend.
- Release APK: arm64-v8a 36.4 MB, armeabi-v7a 32.6 MB, x86_64 38.0 MB (+1.5 MB vs F0: sqflite, share_plus).

## Measurements (F0)
| What | Value |
|---|---|
| First bestmove incl. engine start-up (movetime 500 ms, emulator x86_64, release) | 1139 ms |
| Later bestmoves (movetime 500 ms) | ~502 ms |
| Release APK arm64-v8a | 34.9 MB |
| Release APK armeabi-v7a / x86_64 | 31.1 MB / 36.5 MB |

## Package versions (latest on pub.dev, 2026-10-12)
chessground 10.3.0, dartchess 0.14.0, multistockfish 0.6.1 (Stockfish 19, light flavor), flutter_riverpod 3.4.3, go_router 18.0.2, flutter_animate 4.5.2, sqflite 2.4.4+1, share_plus 13.3.1; dev: flutter_lints 6.0.0, mocktail 1.0.5, sqflite_common_ffi 2.4.3, integration_test (SDK).

## Decisions (F0)
- Engine access goes through a small `UciEngine` interface (real: `StockfishUciEngine`; tests: `FakeUciEngine`). Keeps EngineService testable without native code.
- EngineService starts the engine lazily, so disposing it (detach, hot reload) is always safe; the next request restarts it.
- A superseded search completes with the move found when it was stopped (not an error).
- UCI scores are kept from the side-to-move's point of view; convert to White's view in the UI/review code.
- Board size = shortest side of the free area, so it fits portrait and landscape.

## Decisions (F1)
- **Storage: sqflite, not drift.** One `games` table + one `kv` table. No codegen (ADR-0006), and the same DB code is tested on desktop with sqflite_common_ffi in memory. Drift's type safety is not worth a build_runner step for one table. The DB is opened in `main()` and injected through `appDatabaseProvider`.
- **Strength levels.** Stockfish 19's `uci` output (read on the emulator): `Skill Level` 0..20, `UCI_Elo` 1320..3190. Levels 1–3: `UCI_LimitStrength false`, Skill 0/3/6, depth 1/2/4, 100/150/250 ms (~800/1000/1200). Levels 4–7: `UCI_LimitStrength true`, `UCI_Elo` 1400/1700/2000/2400, 400–1000 ms. Level 8: full strength, 1500 ms (~3000). Ratings are labels, not measurements. Options are set before every search, because the engine restarts with defaults after a dispose.
- **Bot think time** in timed games: min(level time, remaining/30 + increment/2), at least 50 ms.
- **Clock**: immutable `ChessClock` on a monotonic `Stopwatch` time source; the UI ticker only repaints. The clock starts after White's first move (like Lichess); that move gets no increment. Takeback hands the clock back without increment and keeps current times. Paused when the app is hidden and when the game screen is left. Time while the app was killed is not charged.
- **Results**: the 75-move rule and threefold repetition are automatic draws (no 50-move claim). Repetition key = FEN placement + side + castling + legal ep square. Checkmate beats the 75-move rule. Timeout vs insufficient material → draw.
- **Takeback** undoes back to the player's previous turn (bot reply + player move). The UI disables it while the bot thinks; the notifier also cancels any search.
- **Stale bot replies**: every search has a generation number. Takeback, resign, flag and leaving the screen bump it and stop the engine, so a late `bestmove` is dropped even when it is still legal.
- **History saved once**: only from `GameController.onFinished` (fires once); the repository also ignores a repeated id.
- **Autosave** after every move as JSON (UCI moves, replayed on load). Autosave failures are logged, never thrown.
- **Leaving mid-game** pauses the game; "Resume game" continues it. Starting a new game replaces an unfinished one (not saved to history).
- **Board**: chessground `green` scheme, premoves off, chessground's own promotion picker. Castling is stored in UCI as the king move (`e1g1`) even when the board sends king-onto-rook.
- `android/gradle.properties`: `kotlin.incremental=false`. The Kotlin incremental cache fails on Windows when the project (D:) and the pub cache (C:) are on different drives.

## Gate 1 checklist
- [x] Full games vs the engine at a low and a high level: no duplicate engine moves, no stuck thinking (emulator, automated)
- [x] Memory stable over 3 games (emulator RSS, see measurements)
- [x] Tests green locally (120 + on-device integration test)
- [x] CI green after push (run 38223183710)
- [ ] A smooth full game on a real phone (Adaam)
- [ ] Engine timings re-measured on a real arm64 phone

## Known issues / open questions
- multistockfish 0.6.1 always bundles all three engine binaries (light, chess, variant), about 3.4 MB of unused native code per ABI. No pub.dev option to drop them; revisit if the APK size matters (F4).
- chessground ships all its board and piece images (~1,900 files). Most of the APK beyond Flutter itself is these assets. Could be trimmed later if needed.
- Engine timings were measured on an x86_64 emulator, not a real arm64 phone. Re-measure on a phone at Gate 1.
- The first engine reply includes engine start-up (~0.4 s on the emulator). F1 warms the engine (`newGame`) when a game loads, which hides most of it, except when the bot moves first right away.
- Bot ratings per level are estimates. Low levels (Skill Level + depth cap) may feel weaker or stronger than their labels; tune after playing on a phone.
- A game abandoned by starting a new one is dropped, not saved as a loss. Decide in F3 whether it should count.
- The clock widget repaints every frame while a side's clock runs. Cheap, but could be throttled to ~10 fps if battery matters.
- Game screen visuals are minimal (F3 redesign): no move sounds, no captured pieces, no coordinates toggle.
- The scaffold commit already contains the dependency lines in pubspec (they were added before `git init`).
- App name "Langkah" is a working title (change `kAppName` + Android label).
- Context7 and Dart MCP tools did not load in the F0 session (they were added mid-session); APIs were checked from the pub.dev API and package sources instead. A fresh Claude Code session should have them.

## Next
- Adaam: Gate 1 hand check on a real phone (checklist in the F1 hand-off message).
- Then F1.5 — Game Review: engine analysis of a finished game from history, eval bar and graph, move labels, accuracy.

## Environment
- Flutter 3.47.7 stable (D:\dev\flutter), Dart 3.13.5, JDK 21 (Android Studio jbr), Android SDK 36, licenses accepted (2026-10-12)
- Emulator: Pixel_8a_API_35 (system image android-35 google_apis_playstore x86_64 installed 2026-10-12). Other AVDs use the same image.
- GitHub: Syafiyyy/langkah-chess (public)
- Supabase project: not created yet (F2)
