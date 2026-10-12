# STATE

_Single source of project state. Claude Code updates this at the end of every task._

## Current phase
F1 — Core offline: done, including the bot fix (2026-10-12). Gate 1: passed on the emulator after the bot fix; real-phone timing pending (F4, Firebase Test Lab, see ROADMAP). Next: Adaam's hand check of the bot fix, then F1.5 — Game Review.

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

- 2026-10-12: F1 bot fix (prompt `docs/prompts/F1_fix_bots.md`), after Adaam's emulator test: level 1 was far too strong and the bot moved instantly.
  - EngineService: `candidates()` (MultiPV search, latest line per index); MultiPV is reset to 1 before any `bestMove`. Parser reads `multipv`.
  - Levels 1–4 are human-like: `BotMover` gets 10 MultiPV candidates from a full-strength search (depth 6/8/10/12, ≤ 300 ms) and `HumanMovePicker` (pure Dart, seeded `Random`) chooses. Levels 5–7 use UCI_Elo 1400/1800/2200; level 8 is full strength.
  - Natural thinking time (`naturalThinkTime`, `pauseAfterSearch`); "Bot speed" Natural/Fast on the new game sheet (remembered, autosaved); small "Thinking…" spinner on the bot's bar.
  - `core/chess/win_percent.dart` (Lichess win% formula, reused by game review).
  - Calibration test `integration_test/bot_calibration_test.dart` (results below). chess-domain skill: new "Bot behaviour" section.
  - Tests: 154 host tests green (picker: legality, determinism, strength ordering, mate-in-one rates, no two big blunders in a row; thinking time; MultiPV; notifier pause + cancel; new game sheet). Promotion widget test exists and passes (`game_screen_test.dart`: a7-a8, picker, queen).

## Bot calibration (emulator x86_64, 2026-10-12)
Bot vs bot through the app's own `BotMover`, one engine, in-game search settings, Fast speed, real rules (`GameController`), 300 plies = draw, colours alternate. Score is the higher level's.
| Pair | Games | Higher level scored | Avg plies |
|---|---|---|---|
| L1 vs random mover | 10 | 100% | 83 |
| L2 vs L1 | 20 | 58% | 126 |
| L3 vs L2 | 20 | 75% | 127 |
| L4 vs L3 | 20 | 68% | 113 |
| L5 vs L4 | 20 | 73% | 110 |
| L6 vs L5 | 10 | 90% | 86 |
| L7 vs L6 | 10 | 75% | 105 |
| L8 vs L7 | 10 | 100% | 83 |
- Monotonic at every step. Target band 65–80%: L3/L4/L5/L7 steps in band; L2 vs L1 a bit low (with a slightly stronger Beginner it was 85%, so the truth is around 70% ± noise); L6 vs L5 and L8 vs L7 are bigger steps (Stockfish's own scale).
- Noise: 6 games per pair was useless (the same matchup scored 83% and 33% in two runs). 20 games ≈ ±11% standard error.
- Tuning history: first version (softmax-heavy levels 1–4) gave 100% at every low step and level 4 beat level 5 10–0; on/off big blunders then made levels 3–4 indistinguishable. The graded `bigBlunderShare` (0.6 / 0.45 / 0.22 / 0) was what gave a smooth curve.
- Final human styles (temperature / mistake chance / big-blunder share / random move / miss mate-in-1): Newcomer 15 / 0.17 / 0.6 / 0.06 / 0.5; Beginner 12 / 0.14 / 0.45 / 0.02 / 0.25; Casual 10 / 0.12 / 0.22 / 0 / 0.04; Improving 8 / 0.10 / 0 / 0 / 0.015.

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
- **Strength levels (replaced by the bot fix, see below).** Stockfish 19's `uci` output (read on the emulator): `Skill Level` 0..20, `UCI_Elo` 1320..3190. Options are set before every search, because the engine restarts with defaults after a dispose.
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

## Decisions (F1 bot fix)
- **Levels** (Adaam's scale): 1 Newcomer, 2 Beginner, 3 Casual, 4 Improving (human-style), 5 Club (UCI_Elo 1400), 6 Strong club (1800), 7 Expert (2200), 8 Full strength.
- **Labels are honest**: levels 1–4 show only their name. Bot-vs-bot calibration shows relative strength only, so numbers like "~300" could not be justified. Levels 5–7 show "~1400/~1800/~2200" (their UCI_Elo setting, Stockfish's scale). Level 8 shows "Max".
- **Human-style picking** happens in Dart, not via Stockfish's Skill Level: mate in one unless missed → newcomer-only random move → deliberate mistake (drop ≥ 10 win%, big ≥ 30 only by `bigBlunderShare`) → softmax over win% drop. Never two big blunders in a row.
- **Thinking time** at Natural speed: levels 1–4 take 0.6–2.5 s (more legal moves, captures or check → longer; recapture → shorter); forced moves 0.3–0.5 s; levels 5–8 pad to 0.6–1.2 s. The pause counts against the bot's clock and is capped by the same safe budget as the search (1/30 of remaining + half increment). Fast = no pause.
- Natural is the default; the choice is stored with the other new-game choices.
- **Build**: `pubspec.yaml` sets the sqlite3 build hook to `source: system` (Windows `winsqlite3.dll`, Linux CI `libsqlite3-dev`). Otherwise every debug build downloaded a prebuilt libsqlite3 (CI failed once on a hash mismatch). The release APK never contained it; Android uses sqflite's platform SQLite.

## Gate 1 checklist
Gate 1 is checked on the emulator (no Android phone available; see ROADMAP). Status: **passed on the emulator after the bot fix; real-phone timing pending (F4, Firebase Test Lab).**
- [x] Full games vs the engine at a low and a high level: no duplicate engine moves, no stuck thinking (emulator, automated)
- [x] Memory stable over 3 games (emulator RSS, see measurements)
- [x] Tests green locally and in CI (run 38255109365 after the bot fix)
- [x] Adaam's emulator hand test (everything worked except bot strength/speed → fixed, see bot fix)
- [x] Bot levels calibrated and monotonic (table above)
- [ ] Adaam's hand check of the bot fix (5 items in the hand-off message)
- [ ] Engine timings on a real arm64 phone (F4, Firebase Test Lab)

## Known issues / open questions
- multistockfish 0.6.1 always bundles all three engine binaries (light, chess, variant), about 3.4 MB of unused native code per ABI. No pub.dev option to drop them; revisit if the APK size matters (F4).
- chessground ships all its board and piece images (~1,900 files). Most of the APK beyond Flutter itself is these assets. Could be trimmed later if needed.
- Engine timings were measured on an x86_64 emulator, not a real arm64 phone. Re-measure in F4 on Firebase Test Lab physical devices.
- The first engine reply includes engine start-up (~0.4 s on the emulator). F1 warms the engine (`newGame`) when a game loads, which hides most of it, except when the bot moves first right away.
- Bot levels are calibrated against each other, not against humans. Level 1 "Newcomer" should feel very weak, but only Adaam's games can confirm that. Retune `HumanStyle` values and rerun the calibration test if not.
- Level 1 vs 2 is the smallest step (58% in the final run; 85% with a slightly stronger Beginner). Revisit if players feel no difference.
- The calibration test takes ~1.5 h on the emulator (20 games per low pair). It is not part of CI.
- A game abandoned by starting a new one is dropped, not saved as a loss. Decide in F3 whether it should count.
- The clock widget repaints every frame while a side's clock runs. Cheap, but could be throttled to ~10 fps if battery matters.
- Game screen visuals are minimal (F3 redesign): no move sounds, no captured pieces, no coordinates toggle.
- The scaffold commit already contains the dependency lines in pubspec (they were added before `git init`).
- App name "Langkah" is a working title (change `kAppName` + Android label).
- Context7 and Dart MCP tools did not load in the F0 session (they were added mid-session); APIs were checked from the pub.dev API and package sources instead. A fresh Claude Code session should have them.

## Next
- Adaam: hand check of the bot fix on the emulator (5 items in the hand-off message).
- Then F1.5 — Game Review: engine analysis of a finished game from history, eval bar and graph, move labels, accuracy.

## Environment
- Flutter 3.47.7 stable (D:\dev\flutter), Dart 3.13.5, JDK 21 (Android Studio jbr), Android SDK 36, licenses accepted (2026-10-12)
- Emulator: Pixel_8a_API_35 (system image android-35 google_apis_playstore x86_64 installed 2026-10-12). Other AVDs use the same image.
- GitHub: Syafiyyy/langkah-chess (public)
- Supabase project: not created yet (F2)
