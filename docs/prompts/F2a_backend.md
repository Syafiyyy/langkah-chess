# Prompt F2a — Online backend (Supabase) (NEW Claude Code session)

Goal: a correct, tested, server-authoritative backend for online chess. No app UI in this part except what's needed to smoke-test. F2b builds the app side.

## 0. Before coding
- Confirm Dart MCP, Context7 and **Supabase MCP** tools are loaded and the Supabase project (region Singapore) is reachable; if not, stop and tell me.
- Read `CLAUDE.md`, `docs/STATE.md`, ROADMAP (F2 + Gate 2), ADR-0003/0004/0005/0007, the chess-domain skill (online section). If an ADR turns out wrong in practice, stop and propose an ADR change instead of silently diverging.
- superpowers: `writing-plans` (show the plan), `test-driven-development` for SQL functions and the Edge Function.
- Use Context7 for current Supabase docs (RLS, Realtime postgres_changes + RLS, Edge Functions with Deno, pg_cron, auth helpers). Don't rely on memory.

## 1. Repo layout + workflow
- `supabase/` folder via Supabase CLI (`npx supabase init`): `migrations/` (SQL, one file per logical change, never edit an applied migration), `functions/`, `tests/` (pgTAP).
- Local testing: if Docker Desktop is available, use `supabase start` + `supabase test db` for pgTAP. If not, tell me before choosing another approach.
- Apply migrations to the remote project only after local tests pass. Record every applied migration in STATE.
- Secrets: never commit keys. App gets URL + anon key via `--dart-define-from-file=env/dev.json` (gitignored; commit `env/example.json`). Service role key only inside Edge Function secrets.

## 2. Schema (with RLS on every table)
- `profiles` (id = auth.users.id, username unique 3–20 chars [a-z0-9_], avatar key, rating int default 1200, games_played int default 0, created_at). Row created by trigger on signup with a temporary username; user sets the real one once.
- `games` (id uuid, white_id, black_id, status: waiting|active|finished|aborted, mode: invite|matchmaking, time_base_ms, increment_ms, fen, ply int, white_ms, black_ms, last_move_at timestamptz, first_move_deadline timestamptz, result: white|black|draw|null, termination text, invite_code text unique null, draw_offer_by uuid null, created_at, finished_at).
- `moves` (game_id, ply, uci, san, fen_after, white_ms, black_ms, client_move_id uuid UNIQUE, played_by, created_at; PK (game_id, ply)).
- `matchmaking_queue` (user_id PK, time_base_ms, increment_ms, rating, created_at).
- `rating_history` (game_id, user_id, before, after, created_at; UNIQUE(game_id, user_id)).
- RLS: players can SELECT their own games and those games' moves; profiles readable by authenticated users (public fields only); nobody can INSERT/UPDATE/DELETE games, moves, queue or rating rows directly — only via the functions below. Realtime publication on `games` only.

## 3. Server functions (all idempotent, all in Postgres unless noted)
- `apply_move(p_game, p_ply, p_uci, p_san, p_fen_after, p_result, p_termination, p_client_move_id, p_user)` — SECURITY DEFINER, EXECUTE granted to service_role ONLY. In one transaction: `SELECT … FOR UPDATE` the game; if `client_move_id` exists return the stored row; reject if not active / wrong side / `p_ply != ply + 1` (stale); compute mover's clock from `now() - last_move_at`, add increment; if the mover's clock ran out → finish as timeout (with the insufficient-material rule from the chess-domain skill, computed in the Edge Function and passed in); insert move; update game; clear draw offer; if result given → `finish_game`. Return the new game state.
- Edge Function `make_move` (Deno + chess.js): verify JWT → user id; load game; rebuild position from stored FEN; validate the UCI move with chess.js (legal, correct side); compute SAN, new FEN, result/termination (checkmate, stalemate, insufficient material, threefold via move history, 75-move); call `apply_move` with the service role. Return the state. Map errors to clear codes (STALE, NOT_YOUR_TURN, ILLEGAL, GAME_OVER).
- `finish_game(game, result, termination)` (internal): set status, result, finished_at; Elo update per ADR-0007 for both players inside the same transaction; `INSERT … ON CONFLICT DO NOTHING` into rating_history so it can never apply twice.
- RPCs callable by authenticated users (SECURITY DEFINER, check auth.uid()):
  - `create_invite(time_base_ms, increment_ms)` → game in `waiting` with a short unambiguous invite code (e.g. 6 chars, no 0/O/1/I).
  - `join_invite(code)` → assigns colours randomly, sets active, sets `first_move_deadline`. Idempotent if the same user joins twice; rejects joining your own game.
  - `join_queue(time_base_ms, increment_ms)` → pairs with the oldest compatible waiting user using `FOR UPDATE SKIP LOCKED` (no double pairing), else inserts into the queue. `leave_queue()`.
  - `resign(game)`, `offer_draw(game)`, `accept_draw(game)`, `decline_draw(game)`, `abort(game)` (only before both players moved), `claim_timeout(game)` (server checks the clock).
- `pg_cron` every minute: abort games past `first_move_deadline` with no move; flag games where the side to move has run out of time (timeout rule); remove queue rows older than 2 minutes.
- Edge Function `delete_account`: deletes the user's data per policy and the auth user (needed for Play policy later).

## 4. Tests (must pass)
- pgTAP: RLS (a stranger can't read a game; nobody can write tables directly), apply_move (retry with same client_move_id returns same result, stale ply rejected, wrong turn rejected, clocks/increment correct, timeout path), finish_game rating applied once even when called twice, matchmaking never pairs a user twice under concurrent calls, invite join rules, draw/abort/resign rules, cron sweep logic.
- Deno tests for `make_move`: the shared fixture `test/fixtures/tricky_positions.json` (castling, en passant, promotion incl. capture-promotion, checks, mates) must give the same legal-move results as dartchess; add the Dart side test too.
- A smoke script (Dart or Deno) that plays a short game between two test users against the real project and prints the final state.

## 5. Finish
- Update `docs/STATE.md` (schema, functions, migrations applied, test results, decisions, open issues) and add a short `docs/ONLINE.md` (sequence: invite/queue → game → make_move → realtime hint → resync → finish → rating). Commit in logical steps, push, CI green (add a CI job for Deno tests; pgTAP in CI only if it's simple, otherwise document how to run it locally).
- Tell me anything I must do by hand in the Supabase dashboard.
