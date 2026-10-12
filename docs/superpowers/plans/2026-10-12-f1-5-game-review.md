# F1.5 Game Review Implementation Plan

> Executed inline in one session. Spec: `docs/prompts/F1_5.md`. Also in scope (Adaam): "Abandon current game?" when starting a new game while one is in progress; an abandoned game is not saved as a loss.

**Goal:** review any finished game offline: eval bar, eval graph, move labels, accuracy, best-move arrow, cached analysis.

**Architecture:** `EngineService.analyse` streams raw per-position results (side-to-move POV). `features/review/domain` (pure Dart) converts to White POV, computes win%, labels, accuracy. A `ReviewNotifier` (autoDispose family by game id) loads the game, uses the cache or runs the analysis, and fills the state progressively. Widgets only render.

**Layout:** option A (Lichess-style): summary strip, vertical eval bar beside the board, current-move line, fl_chart graph, move list, nav buttons.

## Global constraints
- Stack fixed by ADRs; fl_chart is named in the roadmap. No codegen.
- Review math in pure Dart, TDD. Files under ~300 lines.
- One engine: analysis uses full-strength options and MultiPV 1 (reset by `bestMove`), and stops when the screen closes.

## Decisions (formulas verified against lila source, 2026-10-12)
- Win% = Lichess formula; mate → 100/0 for the mating/mated side. Checkmate/stalemate/insufficient positions are scored without the engine.
- Labels by the mover's win% drop: >= 15 blunder, >= 10 mistake, >= 5 inaccuracy (= lila's 0.3/0.2/0.1 winning-chance deltas). "Best" when the played move equals the engine's best move. No error label when the position was already decided: mover >= 90% before and after (still winning) or <= 10% before and after (already lost).
- Per-move accuracy = lila `AccuracyPercent.fromWinPercents`: 100 if no drop, else `103.1668100711649 * exp(-0.04354415386753951 * drop) - 3.166924740191411 + 1`, clamped 0..100.
- Game accuracy per side = plain mean of that side's move accuracies (lila uses the mean of a volatility-weighted mean and a harmonic mean; documented difference).

## Tasks
1. **Abandon game** (TDD): notifier `abandon()`; home asks "Abandon current game?" before "Play vs Bot" when a game is unfinished. Test: abandoned game never reaches history; autosave cleared.
2. **Review math** (TDD): `PositionEval` (White POV), `toWhitePov`, `winPercentWhite`, `MoveJudgement` labels, accuracy, `ReviewSummary`.
3. **Engine analysis** (TDD): `EngineService.analyse(fens, moveTime, depth) → Stream<AnalysedPosition>`; full-strength options; cancel stops the search.
4. **Cache** (TDD): DB v2 `analysis` table (game_id, settings, engine, json); migration from v1; repository load/save.
5. **ReviewNotifier** (TDD with fake engine): cache hit = instant; miss = progressive fill + save; dispose stops; re-analyse.
6. **UI**: review screen (summary, eval bar, board + arrow, graph, move list, nav incl. prev/next mistake, flip); entry from game-over sheet ("Review game") and replay ("Review"). Widget tests: builds at 360 dp, progressive state, label list.
7. **Device**: on-device analysis of a full game (time per game), tune movetime; STATE, commits, CI.
