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
- Accuracy per move from win% drop; game accuracy = average (document the formula used).
