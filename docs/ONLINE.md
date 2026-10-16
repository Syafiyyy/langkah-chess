# Online play: how the backend works

For whoever builds the app side (F2b). The backend is Supabase project **skak** (`ivznhyyaswhnpdrnnbno`, Singapore). Decisions: ADR-0003 (Supabase), ADR-0004 (server-authoritative idempotent moves), ADR-0005 (Realtime as a hint, resync, server clocks, sweep), ADR-0007 (Elo).

## The rule
The app **never writes tables**. It reads `profiles`, `games`, `moves`, `rating_history` and its own `matchmaking_queue` row (RLS), and changes things only through:
- the Edge Function **`make_move`** (moves),
- the **RPCs** below (everything else),
- the Edge Function **`delete_account`**.

## Sequence

```
 A (creator)                 server                         B
 create_invite(5+2) ───────▶ game: waiting, code "RVMP92"
 (shares the code) ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─▶ join_invite("rvmp92")
                             game: active, colours random,  ◀──
                             first_move_deadline = now+30 s
 ◀── Realtime "games changed" (hint only) ──────────────────▶
 refetch game + moves        │
 White: make_move(ply 1) ──▶ apply_move: lock row, checks,
                             clocks, insert move, update game
 ◀── { game, applied, server_now }   Realtime hint ────────▶ refetch
                                                            make_move(ply 2) …
 …                           mate / stalemate / draw rule /
                             resign / agree / timeout → finish_game:
                             result + Elo for both, once
 ◀── Realtime hint ─────────────────────────────────────────▶ refetch: finished
```

Matchmaking instead of an invite: each player calls `join_queue(base_ms, inc_ms)`. No row back = queued; one row = the game. **While queued, call `join_queue` again every ~30 s**: it is the heartbeat (entries not seen for 2 minutes are dropped) and it returns the game once someone paired with you. Realtime on `games` also tells you. `leave_queue()` to stop.

## Moves: `make_move`
`POST /functions/v1/make_move` with the user's access token:
```json
{ "game_id": "uuid", "ply": 3, "uci": "g1f3", "client_move_id": "uuid" }
```
- `ply` = the move's number (1 = White's first). The game's `ply` is the number of moves made; even ply → White to move.
- `uci` is standard UCI; castling is the king move (`e1g1`), promotion has the piece (`e7e8q`). Use `standardUci` from `features/play_ai/domain/uci_move.dart`.
- `client_move_id`: a new UUID **per move attempt**, reused for every retry of that attempt. A retry of a move that went through returns the game with `applied: true` and never plays twice.

Response: `200 { game, applied, server_now }`. `applied: false` with 200 means the mover's clock had already run out: the game is over on time and the move was not played. Errors: `{ error, server_now }`:

| HTTP | error | Meaning / what to do |
|---|---|---|
| 400 | `BAD_REQUEST` | Malformed body. Bug. |
| 401 | `UNAUTHORIZED` | No or invalid token. Sign in again. |
| 403 | `NOT_A_PLAYER` | Not your game. |
| 404 | `NOT_FOUND` | No such game. |
| 409 | `STALE` | Your `ply` is not the next one: resync. |
| 409 | `NOT_YOUR_TURN` | Resync. |
| 409 | `GAME_OVER` | Resync (it ended: mate, resign, flag, abort). |
| 409 | `DUPLICATE_MOVE_ID` | A `client_move_id` was reused for another game. Bug. |
| 422 | `ILLEGAL` | Server says illegal: resync (client and server rules disagree only on a bug). |
| 500 | `INTERNAL` | Retry the same attempt (same `client_move_id`). |

Client flow (ADR-0004): check legality with dartchess, show the move at once, call `make_move`. On a network error retry with the same id. On any 4xx error: resync and roll back.

## RPCs (`supabase.rpc(name, args)`)
All need a signed-in user. Errors come back as Postgres errors with the code as the message (`error.message == 'USERNAME_TAKEN'`). Game actions return the game; on a game that is already over they change nothing and return it, so retrying is always safe. Every game action settles the clock first, so a flag beats a late resign or draw.

| RPC | Args | Returns | Errors |
|---|---|---|---|
| `set_profile` | `p_username` (null = keep), `p_avatar` (null = keep) | profile | `USERNAME_LOCKED` (set once only), `BAD_USERNAME` (`[a-z0-9_]{3,20}`, not `u_…`), `USERNAME_TAKEN`, `BAD_AVATAR` (`[a-z0-9_]{1,32}`) |
| `create_invite` | `p_time_base_ms` (60 000–3 600 000), `p_increment_ms` (0–60 000) | waiting game with `invite_code` (6 chars, no 0/O/1/I). Same call again returns the same invite. | `BAD_TIME_CONTROL` |
| `join_invite` | `p_code` (any case) | active game | `NOT_FOUND`, `OWN_GAME`, `NOT_AVAILABLE` |
| `join_queue` | `p_time_base_ms`, `p_increment_ms` | 0 rows (queued) or 1 row (game) | `BAD_TIME_CONTROL` |
| `leave_queue` | – | – | – |
| `resign` | `p_game` | game | `NOT_FOUND`, `NOT_A_PLAYER` |
| `offer_draw` | `p_game` | game (`draw_offer_by` = you; if the opponent had offered, it is a draw by agreement) | same |
| `accept_draw` | `p_game` | game | `NO_DRAW_OFFER`, same |
| `decline_draw` | `p_game` | game | same |
| `abort` | `p_game` | game (`aborted`); also cancels your own waiting invite | `CANNOT_ABORT` (both have moved), same |
| `claim_timeout` | `p_game` | game (finished if the side to move has flagged, else unchanged) | same |

All RPCs also raise `NOT_SIGNED_IN` without a user. A move clears any draw offer.

## Realtime and resync (ADR-0005)
- Subscribe to `postgres_changes` on `games` filtered by the game id. RLS lets only the two players (and the invite's creator) see it. Moves are **not** published.
- Treat every event as "something changed": fetch the `games` row and `moves` with `ply >` the last one you have. Do the same on subscribe, reconnect and app resume. The server's state always wins.

## Clocks
- `white_ms` / `black_ms` = time left **as of `last_move_at`**. The side to move's clock runs from `last_move_at`; the other side's is frozen.
- **Clocks start after both players' first moves** (Lichess style): plies 1 and 2 cost no time and get no increment. Instead each first move has a 30 s `first_move_deadline`; missing it aborts the game (`firstMoveTimeout`, unrated).
- Display: `left = (side to move ? stored − (serverNow − last_move_at) : stored)`, with `serverNow = Date.now() + offset`. Get the offset from `server_now` in `make_move` responses (or the HTTP `Date` header of other calls, 1 s precision).
- When the opponent's clock shows 0, call `claim_timeout` (fast path). Otherwise the minute sweep ends it within ~60 s.
- Timeout result: the side out of time loses, unless the other side has no mating material (stored per side as `white_can_mate` / `black_can_mate`), then it is a draw.

## Results
`games.result`: `white` | `black` | `draw` (null while running or aborted). `games.termination` uses the app's `Termination` names plus online ones: `checkmate`, `stalemate`, `insufficientMaterial`, `threefoldRepetition`, `seventyFiveMoveRule` (automatic, as offline), `resignation`, `timeout`, `agreement`, `aborted`, `firstMoveTimeout`, `expired` (invite nobody joined in 24 h). Status: `waiting` → `active` → `finished` | `aborted`.

## Rating (ADR-0007)
Elo, start 1200, K = 32 for a player's first 30 games, then 20. Applied in the same transaction that ends the game, exactly once (`rating_history` primary key `(game_id, user_id)`). Aborted games are unrated. `profiles.rating` / `games_played` are the current values; `rating_history` has before/after per game.

## The minute sweep (pg_cron `skak-sweep`)
Aborts games past their first-move deadline, ends flagged games, aborts invites waiting over 24 h, drops queue entries not seen for 2 minutes. Skips rows a move is holding (`SKIP LOCKED`).

## Account deletion
`POST /functions/v1/delete_account` with the user's token → `{ deleted: true }`. Running games are resigned (rated, so the opponent keeps the win), unstarted games and waiting invites aborted, the queue entry removed; then the auth user is deleted. Profile and own rating history go with it; games and moves stay for opponents with the player set to null (show "Deleted player").

## Config for the app
URL + publishable key only, via `--dart-define-from-file=env/dev.json` (gitignored; `env/example.json` committed). The secret key never goes into the app or the repo.

## Testing
| What | Command | Where |
|---|---|---|
| Edge Function logic (incl. tricky-positions fixture vs chess.js) | `npx deno test --config supabase/functions/deno.json --allow-read supabase/functions` | local, CI |
| Fixture vs dartchess | `flutter test test/online/tricky_positions_test.dart` (`UPDATE_FIXTURES=1` regenerates) | local, CI |
| Database (pgTAP: RLS, apply_move, RPCs, sweep, deletion) | `npx supabase db start` (or `start`), `npx supabase test db` | local, CI |
| Concurrent matchmaking (80 users at once) | `npx deno test --config supabase/functions/deno.json --allow-net --allow-env supabase/integration` | local, CI (needs the local DB) |
| Smoke game on a real project | `supabase/scripts/smoke.ts` (header has the command; needs URL, publishable and secret key in env) | by hand |

Migrations: one file per change in `supabase/migrations/`, never edit an applied one, test locally, then `npx supabase db push`. Edge Functions: `npx supabase functions deploy <name>`.
