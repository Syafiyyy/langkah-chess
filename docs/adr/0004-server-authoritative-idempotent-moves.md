# ADR-0004: Server-authoritative, idempotent moves
Status: Accepted (2026-10-12)

## Decision
1. Client checks legality locally with dartchess and shows the move optimistically.
2. Client calls Edge Function `make_move(game_id, ply, uci, client_move_id)`.
3. Edge Function validates the move with chess.js from the stored FEN and computes new FEN + result. It does NOT write tables itself.
4. It calls one Postgres function `apply_move(...)` (SECURITY DEFINER) that, atomically:
   - locks the game row (`SELECT ... FOR UPDATE`)
   - if `client_move_id` already exists → returns the stored result (safe retry)
   - rejects if game not active, wrong turn, or `ply != current_ply + 1` (stale)
   - computes clocks from `now()` and `last_move_at`; flags timeout
   - inserts into `moves` (PK `(game_id, ply)`, `client_move_id` UNIQUE), updates `games`
   - finishes the game and writes rating in the same transaction when the game ends
5. On rejection, client resyncs from the server and rolls back.

Moves cross the client/server boundary as **UCI only**. Positions are compared by placement, side to move, castling and en-passant (ignore move counters). A shared tricky-positions fixture must pass on both dartchess and chess.js.

## Why not one transaction inside the Edge Function?
supabase-js calls are separate HTTP requests; there is no shared transaction. Atomic work belongs in Postgres.

## Consequences
+ Retries are safe; moves can't be lost, duplicated or forged.
- An extra hop (Edge Function) adds latency and cold starts; measure it and report it in the README.
