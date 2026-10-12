---
name: chess-domain
description: Rules and conventions for Langkah's chess logic, engine and online game code. Use for ANY work touching dartchess, chessground, multistockfish/EngineService, clocks, game results, PGN, game review, or online moves (make_move/apply_move).
---

# Chess domain rules (Langkah)

## Libraries and their jobs
- `dartchess`: the ONLY source of chess rules on the client (legal moves, FEN, SAN, PGN, outcome). Never hand-roll move legality.
- `chessground`: rendering + input only. Board state comes from a dartchess `Position`; update via the controller, never by mutating widget state.
- `multistockfish` (light flavor): only through `core/engine/EngineService`. Check the current API with Context7 / pub.dev example. Ignore the old root README of lichess-org/dart-multistockfish (`Stockfish.instance`, SF16).

## EngineService rules
- Exactly one service instance (Riverpod provider, keepAlive). One engine per flavor can exist at a time; creating a second throws.
- Subscribe to stdout ONCE when the engine is created. Route output to the current request via a request id / completer. Never call `stdout.listen` per move.
- Every search: `stop` the previous search, `ucinewgame` for a new game, `position fen <fen>` (or startpos + moves), then `go ...`. Wait for `readyok` after setoption.
- Strength: `setoption name UCI_LimitStrength value true` + `setoption name UCI_Elo value <n>`; play mode uses `go movetime <ms>`.
- Analysis (game review): `go depth <n>` or movetime per position, parse `info ... score cp|mate ... pv`, cancellable, runs only when the user is on the review screen.
- Dispose the engine when the app is detached; in debug, dispose before hot reload.
- Never send an unvalidated FEN to the engine (illegal positions can crash it). Validate with dartchess first.

## Bot behaviour (offline play)
- Levels and their engine settings live in one table: `features/play_ai/domain/bot_level.dart`. Levels 5–7 use `UCI_LimitStrength` + `UCI_Elo` (Stockfish 19 range 1320..3190); level 8 is full strength.
- Levels 1–4 never play Stockfish's bestmove directly (Skill Level / UCI_Elo don't blunder like beginners). `BotMover` asks for MultiPV candidates (`EngineService.candidates`), and `HumanMovePicker` (pure Dart, seeded `Random`) chooses: mate in one unless missed (levels 3–4 almost never miss) → newcomer-only random legal move → deliberate mistake (drop >= 10 win%) → softmax over win% drop with the level's temperature.
- Guardrails: only legal moves; never two big blunders (drop >= 30 win%) in a row; one picker per game.
- MultiPV: `candidates()` sets it; `bestMove()` resets it to 1 first. Analysis (game review) must use MultiPV 1 unless it asks for candidates on purpose.
- Thinking delay: at "Natural" bot speed the move appears after `naturalThinkTime` (0.6–2.5 s for levels 1–4, by position complexity; quicker for forced moves and recaptures; levels 5–8 only pad to 0.6–1.2 s). In timed games search + pause stay within `safeThinkBudget` (1/30 of the bot's clock + half the increment), so the pause can never flag the bot. "Fast" skips the pause. Takeback/resign/flag/leaving drops a pending move (generation check).
- Calibration is required after changing any level: run `integration_test/bot_calibration_test.dart` (level N vs N+1, target: the higher level scores ~65–80%) and record the table in `docs/STATE.md`. Don't relabel ratings without evidence.

## Game results (must be unit-tested)
- Checkmate, stalemate, threefold repetition, 50-move rule, insufficient material, resignation, draw agreement, timeout.
- Timeout: the side that ran out LOSES, unless the OTHER side has insufficient mating material → draw. Custom function, own tests.

## Moves across boundaries
- Always UCI strings (`e2e4`, `e7e8q`). Castling as king move (`e1g1`).
- Compare positions by board placement + side to move + castling rights + en-passant square. Ignore halfmove/fullmove counters.
- `test/fixtures/tricky_positions.json`: castling, en passant, promotions (incl. capture-promotion), checks, mates. Must pass on dartchess (Dart tests) and chess.js (Edge Function tests).

## Online (see ADR-0004, ADR-0005)
- Client never writes `games`/`moves`. Call Edge Function `make_move(game_id, ply, uci, client_move_id)`; `client_move_id` is a UUID generated once per move attempt and reused on retry.
- Optimistic local move → on reject: resync from server, roll back.
- Realtime is a hint; on subscribe/reconnect/resume always fetch game + moves after last ply.
- Clock display = server clocks minus elapsed since `last_move_at`, corrected with server-time offset.

## Game review labels (win-probability based)
- Convert centipawns to win% (Lichess formula: `50 + 50 * (2 / (1 + exp(-0.00368208 * cp)) - 1)`).
- Label by win% drop for the mover (Lichess uses winning-chance drops of 0.3/0.2/0.1 on a -1..1 scale, i.e. 15/10/5 win% points): >= 15 blunder, >= 10 mistake, >= 5 inaccuracy. Tune if needed and document in code.
- Implemented in `features/review/domain/move_review.dart` (win% in `core/chess/win_percent.dart`). Engine scores become White's view in exactly one place: `PositionEval.fromSideToMove`. Finished positions (mate/stalemate/insufficient) are scored without the engine.
- "Best" when the played move equals the engine's best move. No error label when the game was already decided: mover >= 90% before and after, or <= 10% before and after.
- Per-move accuracy = lila `AccuracyPercent.fromWinPercents`: 100 without a drop, else `103.1668100711649 * exp(-0.04354415386753951 * drop) - 3.166924740191411 + 1` (the +1 is lila's "uncertainty bonus"), clamped 0..100. Game accuracy per side = plain mean (lila uses the mean of a volatility-weighted mean and a harmonic mean).
- Analysis: `EngineService.analyse` (MultiPV 1, full-strength options set first), 350 ms per position, cached in the `analysis` table keyed by game id + settings + engine build. Change the settings string when the settings change.
