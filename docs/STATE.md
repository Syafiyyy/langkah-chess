# STATE

_Single source of project state. Claude Code updates this at the end of every task._

## Current phase
App renamed **Skak** (formerly Langkah) on 2026-10-13, before F2.
F1.8 — Design system + offline redesign: done (2026-10-13), plus F1.8b polish pass from Adaam's screenshot review. F1.5 Game Review done; Gate 1.5 (demo clip) pending Adaam's hand check. Gate 1 passed on emulator; real-phone timing pending (F4, Firebase Test Lab). Next: Adaam's hand check of the redesign, then F2 — Online.

## Done
- 2026-10-12: Planning. v1 analysed, stack researched, blueprint independently reviewed, ADR-0001..0007 written, roadmap set. Kickoff docs created.
- 2026-10-12: F0 Foundation.
  - Tooling verified: dart-flutter plugin (Dart MCP), Context7 MCP, superpowers, gh (Syafiyyy). Skills karpathy-rules + frontend-design copied unchanged from DriveCover.
  - Flutter project created (`com.syafiyyy.skak`, Android only, Kotlin DSL, one gradle setup). App name constant: `lib/app/app_info.dart` (+ Android manifest label).
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

- 2026-10-12: Abandon game. "Play vs Bot" with an unfinished game asks "Abandon current game?" (Keep game / Abandon game). Abandoning deletes the autosave; the game never reaches history (not a loss).
- 2026-10-12: F1.5 Game Review (prompt `docs/prompts/F1_5.md`, plan `docs/superpowers/plans/2026-10-12-f1-5-game-review.md`).
  - `EngineService.analyse(fens)`: MultiPV-1 search per position, streamed; cancelling stops before the next position.
  - Review math (`features/review/domain`, pure Dart): `PositionEval` (White POV, flipped in one place), win%, labels, Lichess per-move accuracy, per-side summary. `GameLine` replays the saved PGN.
  - Cache: DB v2 `analysis` table (game id + settings + engine build); v1 → v2 migration keeps existing games.
  - `ReviewNotifier` (autoDispose family by game id): cache hit = instant; else analyses at full strength, fills progressively, saves the cache; leaving the screen stops the engine; navigation by ply and between the player's own errors.
  - Review screen (layout A, Lichess-style): summary strip (accuracy + ?! ? ?? per side), vertical eval bar + board with the engine's best move as an arrow, current-move verdict line with score / progress, fl_chart win% graph (progressive fill, tap/drag to jump, mistakes/blunders dotted), move list with marks, flip / move / your-mistake navigation, re-analyse. Entry points: "Review game" on the game-over sheet, "Review" on the history replay.
  - Tests: 188 host tests green (review math incl. boundaries and a full Fool's mate review; analysis stream; cache + migration; notifier with fake engine; review screen at 360 dp; abandon flow). On-device: `integration_test/review_analysis_test.dart`.

- 2026-10-13: F1.8 Design system + offline redesign (prompt `docs/prompts/F1_8_design.md`, plan `docs/superpowers/plans/2026-10-12-f1-8-design-system.md`).
  - "Songket" tokens in `lib/app/theme/` (colours, type scale, radii, spacing, motion); theme rebuilt from them. Fonts bundled as static TTFs (Sora 600/700, Plus Jakarta Sans 400/500/700, DM Mono 500; OFL licences in `assets/fonts`).
  - Board themes (songket default with woven lattice frame, walnut, graphite) and piece sets (Classic/cburnett default, Merida, California, Staunty), saved in the kv store, used by every board (game, review, replay, settings preview).
  - Shared widgets in `lib/shared/widgets/`: Wordmark, TileButton, PlayerBar, ClockChip, ThinkingDots, SectionCard, showAppSheet, showConfirmDialog, BoardFrame, ThemedBoard, MoveList.
  - Restyled: home, new game sheet (level names + descriptions), game screen (wordmark top bar + menu, avatar player bars, framed board, gold active clock, DM Mono move strip with pill, four 60 px tiles incl. Moves sheet), game-over sheet, abandon/resign dialogs, history, replay, review. New Settings screen (preview, theme cards, piece cards, default bot speed), reachable from Home and the game menu.
  - Launcher icon (adaptive + Android 13 monochrome) and native splash (navy + gold rhombus, no delay).
  - `.claude/skills/skak-design/SKILL.md`; CLAUDE.md loads it for UI work.
  - Tests: 237 host tests green, incl. contrast test, board theme/prefs, settings screen, abandon/home, history empty states, custom time dialog validation, game menu clock pause, goldens (Home/Game/Review 390x844).
  - Fixed along the way: rematch kept the old bot speed default; resumed games opened with the move strip scrolled away from the latest move; theme swatches rendered 0 px; clock kept running while Settings was open from a game.
  - Screenshots (release build, emulator, real fonts) in `docs/screenshots/`.
- 2026-10-13: F1.8b polish (prompt `docs/prompts/F1_8b_polish.md`, from Adaam's screenshot review).
  - Game screen: bot bar + board + player bar are one block (8 px gaps, bars 48 px); spare height split above and below. The status line has reserved room under the block, so the board never jumps when it appears. Compact gold current-move pill (28 px, navy text) in a 48 dp tap row; move strip is a rounded L1 card on the 16 px gutter, full width even with few moves. Bot bar shows the persona ("Beginner") with "Level 2 · Bot".
  - Review: error counts are dot + label ("1 Blunder"), zero counts hidden, "No errors" when none. Summary → board/eval bar → verdict → graph as one centred block. Eval graph 128 px (72 px if the board would drop under 240 px), rounded card, dashed midline.
  - Home: "Recent games" (last 3: level, W/L/D badge, accuracy if reviewed, date; tap → replay) with a stats row (games · wins · best accuracy) and a first-use empty state ("Start a game"). "View all" opens History (the History card is gone). Settings icon removed from the app bar; the Settings card stays.
  - `historyRevisionProvider`: bumped when a game is saved or a review is cached; Home summary and History lists watch it.
  - Tests: 254 green (home summary, recent games, revision bump, game layout incl. 360x640 and pill/gutter, review chips/graph height/board theme). Goldens and all screenshots updated.

## Contrast ratios (WCAG, checked in `test/app/theme/contrast_test.dart`)
| Text | on ground #101826 | on surface #18233A | on raised #1F2C48 |
|---|---|---|---|
| text #F3EEE3 | 15.37 | 13.54 | 12.00 |
| textMuted #AFB8C9 | 8.91 | 7.85 | 6.96 |
| accent #D9A93F | 8.21 | 7.23 | 6.41 |
| danger #FF7B6E | 7.04 | 6.20 | 5.50 |
| success #5ED39A | 9.54 | 8.40 | 7.45 |
| labelBest #8FD98A | 10.55 | 9.30 | 8.24 |
| labelInaccuracy #F2D46B | 12.20 | 10.75 | 9.53 |
| labelMistake #F39A4E | 8.08 | 7.12 | 6.31 |
| labelBlunder #FF6B6B | 6.41 | 5.65 | 5.00 |
| textFaint #7D879B (disabled/decor only) | 4.92 | 4.34 | 3.84 |
- onAccent #101826 on gold #D9A93F: 8.21 (pressed #EBC56B: 10.78).
- Label lightness (L*): inaccuracy 85.5, best 80.3, mistake 71.4, blunder 64.0 (>= 5 steps apart).

## Measurements (F1.8)
- Release APK: arm64-v8a 37.1 MB, armeabi-v7a 33.4 MB, x86_64 38.7 MB (+0.7 MB vs F1.5: bundled fonts ~0.46 MB + brand assets).

## Measurements (F1.5, emulator x86_64)
| What | Value |
|---|---|
| 40-move game (81 positions), 250 ms/position | 24.0 s |
| 40-move game, 350 ms/position (chosen) | 31.9 s |
| Reopening a reviewed game (cache) | 21–31 ms |
- Time is almost device-independent (move time × positions + ~15% overhead); a slower phone just searches less deep. Real-phone check: F4, Firebase Test Lab.

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
chessground 10.3.0, dartchess 0.14.0, multistockfish 0.6.1 (Stockfish 19, light flavor), flutter_riverpod 3.4.3, go_router 18.0.2, flutter_animate 4.5.2, sqflite 2.4.4+1, share_plus 13.3.1, fl_chart 1.2.0; dev: flutter_lints 6.0.0, mocktail 1.0.5, sqflite_common_ffi 2.4.3, integration_test (SDK), flutter_launcher_icons 0.14.4, flutter_native_splash 2.4.8.

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

## Decisions (F1.5)
- Formulas checked against lila source on 2026-10-12: win% = Lichess formula (mate = 100/0); labels by the mover's win% drop >= 15 / 10 / 5 (= lila's 0.3 / 0.2 / 0.1 winning-chance thresholds); "Best" = played the engine's move; no error label when the game was already decided (mover >= 90% before and after, or <= 10% before and after); per-move accuracy = lila `AccuracyPercent.fromWinPercents` incl. its +1 bonus; game accuracy = plain mean per side (lila: mean of volatility-weighted and harmonic means).
- Analysis: 350 ms per position (~32 s for 40 moves; target was 30–45 s), full-strength options set first, MultiPV 1. Cache key `movetime350` + `stockfish19-light/multistockfish-0.6.1`.
- "Your previous/next mistake" means the player's own inaccuracies, mistakes and blunders; the buttons are disabled when there is none that way.
- Layout A (Lichess-style) over a horizontal eval bar (unusual) and tabs (hide the graph or summary).
- Abandoned games are deleted, not saved as losses (Adaam, 2026-10-12).

## Decisions (F1.8)
- Direction approved by Adaam (mockups in claude.ai); tokens exactly as specified. Danger #FF7B6E and success #5ED39A chosen for >= 4.5:1 on all surfaces.
- `textFaint` (given #7D879B) fails 4.5:1 on surface/raised, so it is restricted to disabled controls and decoration.
- Deviations from the vectorlab skills (Adaam's spec wins): weights include 700 (Sora wordmark, PJS stat numbers only; body text 400/500); type scale 12/13/15/17/20/24/32 (body 15, not 16); motion 120/200/320 ms with one easing (not 100/150/200/300).
- chessground has one last-move highlight colour: each theme uses a translucent overlay solved offline to land near both target colours (walnut within ~1 step, graphite ~4, songket ~8).
- Every board goes through `GameBoard` / `ThemedBoard` / `BoardFrame`, so theme, pieces and frame apply everywhere. Eval bar/graph use shell colours.
- Icons: Material rounded set only.
- Goldens render text in Flutter's test font (boxes): real fonts rasterise 7–11% differently on Windows vs Linux CI. Goldens check layout, colours, boards and icons; `docs/screenshots` show real type. Comparator tolerance 3%.
- Opening Settings from a game pauses the clock (it resumes on return).
- Brand PNGs drawn by a small Pillow script (not committed; mark = gold rhombus #D9A93F on #101826).

## Decisions (F1.8b)
- Avatar dot: kept as a **side-to-move indicator** (solid gold dot with a ground ring on the player whose turn it is; none when the game is over). The old piece-colour dot read like a presence dot; board orientation already shows colours.
- Current-move pill: gold fill + navy text (8.21:1), not raised fill + gold text: raised on surface is too subtle to find at a glance.
- Review error counts: plain dot + text, no pill backgrounds (static information; anti-slop).
- Item 8 (review board on Graphite while Settings showed Songket): not a bug. The review screenshot was captured after switching to Graphite for the theme shots. A test now pins the review board to the chosen theme.
- Home accuracy comes from the cached review (same analysis key as the review screen); unreviewed games show no accuracy and Home never starts an analysis.

## UX audit (vectorlab ux-audit, 2026-10-13; re-run for F1.8b on Home, Game, Review)
- F1.8b: verb-first labels ("Start a game", "View all"); first-use empty state has header, value sentence and action; no decorative pills on static counts; no new motion; tap targets 48 dp (move items, View all, list rows 56+); no overflow at 360x640 (tests); visual pass from the new screenshots. No hard-rule fails.
- Fixed: custom time dialog (no disabled submit; blur validation; clear on edit), verb-first labels, actionable empty states in History, motion limited to transform/opacity (clock chip, eval bar) and reduced-motion for board animations, 48 dp move pills.
- Unproven (no device a11y tooling run): TalkBack reading order, focus order with a hardware keyboard, reduced-motion on a device with "Remove animations" on.

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
- Review: the engine-best arrow is shown for the position on the board (what to play next), not the alternative to the move just played; the verdict line names the better move ("best Qe7") for errors.
- Review accuracy is the plain mean, so it can differ a few points from Lichess for the same game.
- Optional F1.5 item "Review a PGN" (paste/import) not built; ask Adaam first.
- The clock widget repaints every frame while a side's clock runs. Cheap, but could be throttled to ~10 fps if battery matters.
- Still missing from the game screen (F3 polish): move sounds, captured pieces, coordinates toggle, haptics.
- Graphite's frame (#1E242E) is close to the navy ground, so the board looks frameless in that theme. Fine for now; revisit with a lighter frame if Adaam wants.
- Replay screen still has the old loose vertical rhythm (board centred, empty bands); not in the F1.8b list. Apply the game-screen block layout there next.
- Home date uses the device clock/locale (`formatShortDate`), no relative "today".
- During scripted emulator taps the piece set once switched to Merida without an intended tap; a clean re-run behaved correctly and it did not reproduce. Watch for it in the hand check.
- Material sheet/dialog/page transitions do not follow reduced motion automatically (only our own animations do).
- The scaffold commit already contains the dependency lines in pubspec (they were added before `git init`).
- The local folder is still `D:\Projects\langkah-chess` on purpose (Claude Code local-scope plugins and MCP config are tied to that path). Everything else uses Skak.
- Old dev installs of `com.syafiyyy.langkah` are a separate app; uninstall them by hand (`adb uninstall com.syafiyyy.langkah`).
- Context7 and Dart MCP tools did not load in the F0 session (they were added mid-session); APIs were checked from the pub.dev API and package sources instead. A fresh Claude Code session should have them.

## Next
- Adaam: hand check of the F1.8b polish (5 items in the hand-off message); record the Gate 1.5 demo clip with the new look.
- Then F2 — Online (Supabase).

## Environment
- Flutter 3.47.7 stable (D:\dev\flutter), Dart 3.13.5, JDK 21 (Android Studio jbr), Android SDK 36, licenses accepted (2026-10-12)
- Emulator: Pixel_8a_API_35 (system image android-35 google_apis_playstore x86_64 installed 2026-10-12). Other AVDs use the same image.
- GitHub: Syafiyyy/skak-chess (public; renamed from langkah-chess, GitHub redirects old links)
- Supabase project: not created yet (F2)
