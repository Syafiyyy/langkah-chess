# STATE

_Single source of project state. Claude Code updates this at the end of every task._

## Current phase
**F2b — Online in the app: done (2026-10-17).** All four checkpoints done; **Gate 2 passed on two emulators**, rematch included. Google sign-in is configured and works up to Google's own account screen; the last step needs a real Google account on a device (Adaam's hand check). `make_move` was sped up (v4: about half the time). Next: Adaam's hand check, then F3. See "F2b resume here".
Migrations `20261016000100_expire_invites` and `20261016000200_rematch` are on skak (Adaam, `npx supabase db push`, 2026-10-17).

App renamed **Skak** (formerly Langkah) on 2026-10-13, before F2.

## F2b resume here (read this first)
Prompt `docs/prompts/F2b_app.md`, plan `docs/superpowers/plans/2026-10-16-f2b-app.md`. Contract: `docs/ONLINE.md`.

| Checkpoint | Status |
|---|---|
| 1. Auth + profile | **Done.** Verified on the emulator against skak (wrong-password message, sign in, taken-name check, username saved, online home with rating). |
| 2. Online entry screens | **Done.** Verified on two emulators against skak: invite created (3+2), joined from B through the `skak://join/CODE` link, both opened the same game; quick match 1+0 paired both within ~6 s (Realtime hint, not the 30 s heartbeat). |
| 3. Online game screen | **Done.** Played on two emulators against skak (see Gate 2). Rematch untested on a device until `20261016000200_rematch` is pushed. |
| 4. Gate 2 test | **Done** (see Gate 2 checklist). |

**Checkpoint 1 notes:**
- Packages: supabase_flutter 2.18.3, google_sign_in 7.2.0, app_links 7.2.2, uuid 4.6.0, http 1.6 (direct, for the Date-header client).
- Config: `--dart-define-from-file=env/dev.json` (`SUPABASE_URL`, `SUPABASE_ANON_KEY` = publishable key, `GOOGLE_WEB_CLIENT_ID`). Without URL/key, or if `Supabase.initialize` throws, the app runs offline only and "Play online" says so. `env/dev.json` exists locally (gitignored) with skak's URL + publishable key; the Google id stays empty until Adaam creates the OAuth clients.
- `ServerClock` (`core/supabase/server_clock.dart`): offset from make_move `server_now` (exact) or the HTTP `Date` header of any Supabase response (+500 ms, ignored for 60 s after an exact sample), fed by `DateHeaderClient` passed to `Supabase.initialize`.
- `/online` and `/profile` sit behind `OnlineGate`: not configured → message; signed out → sign in; `username_set` false → username screen; else the page. No go_router redirects.
- Sign in: email + password, "Create account" toggle (email confirmation link goes to `skak://login-callback`), Google only when `GOOGLE_WEB_CLIENT_ID` is set (google_sign_in 7 / Credential Manager, then `signInWithIdToken`). Auth error codes mapped to plain messages.
- Username: rules on blur (`[a-z0-9_]{3,20}`, not `u_`), then an availability read; the server's `USERNAME_TAKEN` still wins on save. `BlurField` (shared) unfocuses on a tap outside: Android kept the focus, so blur checks never ran (found on the emulator).
- Profile: username, rating, rated games, sign out, delete account (type the username to enable "Delete account"; calls `delete_account`, then signs out).
- Android: INTERNET permission in the main manifest (release builds had none), `skak://` VIEW intent filter, `flutter_deeplinking_enabled=false` (app_links reads links).
- `Termination.agreement` added (online draws by agreement).
- Test users for Gate 2 on skak: `gate_a@example.com` (username gate_a), `gate_b@example.com`; passwords in gitignored `env/test_users.json` (made with the Admin API, like the F2a smoke users).
- Tests: Flutter 285 green (+ server clock, username rules, auth screens incl. 360x640, online clock/result domain).
- `Supabase.initialize` stays awaited in `main()`: it only reads local storage (session recovery is not awaited; checked in the 2.18.3 source). Warm start 2 s to init on the emulator; a freshly booted emulator's first debug start took 24 s (JIT), not network.

**Checkpoint 2 notes:**
- `OnlineApi` (`features/online/data/online_api.dart`) is the only door to the server; `SupabaseOnlineApi` implements it with a 10 s timeout per request. Failures: `OnlineRejected(code)` (4xx / RPC error code, SQLSTATE P0001) or `OnlineUnavailable` (network, timeout, 5xx). make_move responses (and error bodies) feed `server_now` into `ServerClock`.
- Routes: `/online` with nested `invite?tc=`, `join?code=`, `search?tc=`, `game/:id`, all behind `OnlineGate`. `tc` is built with `Uri` (a raw `+` decodes as a space).
- Time controls online: presets 1+0, 3+2, 5+0, 10+0, 15+10, 30+0 (the bot's custom dialog allows up to 180 min; the server caps at 60).
- Invite screen: `create_invite` (returns the same waiting invite again), big code, Share (share_plus), `skak://join/CODE`, waiting, Cancel (= `abort`). Watches the game (Realtime + 15 s poll + on resume); active → game; aborted shows "This invite expired" (termination `expired`) or "cancelled", with "Create new invite".
- Join: 6 chars, upper-cased, only A–Z/0–9; errors NOT_FOUND / OWN_GAME / NOT_AVAILABLE in plain words. `skak://join/CODE` (app_links, `lib/app/deep_links.dart`) opens it and joins right away (after sign-in if needed).
- Quick match: `join_queue` at once, every 30 s (heartbeat) and on every Realtime change to a game where the player is White or Black (`watchMyGames`); elapsed time; "Stop searching" / leaving = `leave_queue` (not after pairing).
- Online home: profile card, "Resume game" when a game is active, Invite / Join / Quick match.
- `ThinkingDots` takes a label and may wrap (overflowed at 360 dp with long labels).
- Tests: Flutter 300 green (+ deep links, entry screens with `FakeOnlineApi`).

**Checkpoint 3 notes:**
- `OnlineGameNotifier` (`onlineGameProvider(gameId)`, AsyncNotifier family, no auto-retry): first load = game + all moves + players; Realtime `watchGame` (hint only), a 20 s poll while active, `appResumed()` and (re)subscription all run one serialised resync (`fetchSnapshot`: game row + moves after the last known ply; full refetch if they don't chain). A snapshot with a lower ply than the current one is dropped (lost a race with a make_move response).
- Moves (`online_move_sending.dart`): legal check with dartchess, `standardUci`, optimistic `PendingMove` with one UUID; network errors retry with the same id after 0.5/1/2/4 s, then a resync, then every 5 s while the screen is open (so a move made during a 20 s outage is still delivered; the prompt said "max ~5 tries", but giving up would lose the move). Rejections (STALE/NOT_YOUR_TURN/GAME_OVER/ILLEGAL) roll back with a short non-blaming notice and a resync. `applied:false` = flagged, the game is over.
- Clocks: `remainingTime` from the server row + `ServerClock`; the player's own clock freezes at the moment of an optimistic move. `TimeoutClaimer` calls `claim_timeout` once per ply 300 ms after the opponent's computed flag (also the first-move deadline). The minute sweep is the fallback.
- Screen: reuses GameBoard, PlayerBar, MoveList, moves sheet, TileButton. Controls Flip / Moves / Draw (offer, or accept when offered; off before both moved) / Abort (before both moved) or Resign (confirm dialogs name the action). Status line: browsing, notices (Dismiss), draw offer (Decline / Accept draw), first-move countdown, rematch offer, result. "Reconnecting…" replaces the app bar title (a banner above the board moved the board: found on the emulator).
- Result sheet: `GameOverSheet` generalised (`GameOverInfo` + actions map; offline unchanged). Online: You won/lost/Draw/Game aborted, reason, moves, "Rating +15" (rebuilds live: the rating change arrives after the sheet opens), Review game / Offer or Accept rematch / Back to online.
- Rematch: migration `20261016000200_rematch.sql` (`games.rematch_code`, `rematch_by` + index; RPC `offer_rematch(p_game)`: offer = invite with the same time control, code stored on the finished game; the opponent's offer = `join_invite`; a dead earlier offer is replaced). pgTAP `07_rematch.test.sql` (12). The offerer waits on the invite screen (create_invite returns that invite). Not on skak yet.
- History: DB v3 (`games.opponent`, `games.rating_change`; online games have `bot_level` 0); labels "vs name". A finished game is saved once (`recordFinishedGame`), and History runs `syncOnlineHistory` (last 50 finished server games not cached yet; offline = no-op). Review shows the opponent's name instead of "Bot".
- Fixed on the emulator: postgrest-dart `.order()` is descending by default, so the full move list came back reversed (board fell back to the start). Now `ascending: true`. The fake API returned sorted lists, so tests could not see it.
- Notifier split to stay near 300 lines: `online_move_sending.dart` (part), `online_sync.dart`, `timeout_claimer.dart`, `online_game_over.dart`.
- `make_move` round trip is logged (`debugPrint('make_move ply n: x ms')`).
- Tests: Flutter 332 green, pgTAP 147 green (local; the local DB had leftover rows from an earlier run and needed `npx supabase db reset --local`).

## Gate 2 checklist (2026-10-16, two emulators: Pixel 9 API 35 = gate_a, Pixel 8a API 35 = gate_b, debug builds, real skak project)
- [x] Full invite game: invite → `skak://join/CODE` on the other device → both on the same game → played → B resigned through the UI: "You won · Rating +15" / "You lost · Rating −15" on both, Review opens it (game 7MSSRA).
- [x] Quick-match game: both queued 1+0 and were paired in ~6 s (Realtime hint).
- [x] Network off on one device for 20 s (airplane mode), a move made during the outage, network back: the move reached the server and the other device once (moves table: plies 1–5, 5 distinct client_move_ids); "Reconnecting…" while offline, cleared when the channel was back.
- [x] One app in the background 60 s while the opponent moved; on resume the move was there and both screens showed the same clocks to the second (3:10 / 4:04).
- [x] Fast double-tap / repeated move: 5 taps → one make_move call, one row for ply 7.
- [x] Clock ran out (1+0 quick match, both apps open): timeout shown on both, claimed by the opponent's app 57.1 s after the last move (not the minute sweep); `rating_history` 2 rows (1231→1244, 1169→1156). A second timeout (game LBMBL7) ended by the sweep while no app was open: rated once.
- [x] First-move deadline: missed twice during scripting; both devices showed "Game aborted · No first move in time · not rated".
- Fixed 2026-10-17 (found on the emulator): Sign out / Delete account left the player on a sign-in screen at /profile (OnlineGate swapped the page out before its `context.go('/')`); the router is now taken first. Widget test added.
- [x] Rematch (2026-10-17, after the push): B resigned, A tapped "Offer rematch" and waited on the invite screen; B's result sheet switched live to "Accept rematch"; tapping it put both in a new active 5+0 game between the same players (old BEFL45 → `rematch_code` NGNSTB, offered by gate_a; colours drawn again).
- [~] Google sign-in (2026-10-17): button shown with `GOOGLE_WEB_CLIENT_ID` set; tapping opens Google's Credential Manager flow; with no Google account on the emulator it opens "Sign in - Google Accounts" (add an account), and backing out returns to the sign-in screen with no error (cancel path). Not completed: needs a real Google account on the device. Skip nonce checks is OFF in Supabase (google_sign_in 7 on Android sends no nonce); if Adaam's test fails with a nonce error, turn it on.

## Measurements (F2b, make_move latency from Kuala Lumpur → skak ap-southeast-1)
`supabase/scripts/latency.ts` (Deno, publishable key + test users' passwords) plays a 20-ply Ruy Lopez through make_move and times every call; the app logs `make_move ply n: x ms`.
| What | v3 (5 sequential calls) | v4 (parallel reads, 2026-10-17) |
|---|---|---|
| Edge Function execution (`function_edge_logs`), median / min / max | 1185 / 657 / 1744 ms (n 20) | 656 / 499 / 2541 ms (n 33; max = cold start) |
| Script round trip, warm, median / min / max | – | 721 / 566 / 1053 ms (20 calls) |
| Script, first call after 18 min idle | – | 1047 ms, then median 820 ms (max 1026) |
| Script, first call right after the deploy (cold worker) | – | 3910 ms; the next two (new connections) 2.6 s, then 0.6–1.3 s |
| App on the emulators, per move | 1292–1941 ms, median ~1.55 s (n 8) | 843–1131 ms (n 4) |
- v4 (`make_move` deployed 2026-10-17, verify_jwt still on): `auth.getUser`, the game row, the move-id lookup and the move history run at once (`Promise.all`), then `apply_move`: 2 sequential hops instead of 5. Nothing is returned before the user check; UNAUTHORIZED still comes before BAD_REQUEST. Deno tests 41.
- Cold start is a fresh worker (after a deploy, or presumably after a long idle); 18 minutes of idle did not cause one.
- Further option (not done): read the user id from the JWT the gateway already verified instead of `auth.getUser` (saves a call only when that call is the slowest of the parallel ones).
- For the README (F4): "a move takes ~0.7–1 s server round trip from Malaysia (median ~0.8 s), ~4 s on a cold worker; the mover sees it instantly (optimistic), the opponent after the round trip + Realtime."

## F2a resume here (read this first)
Prompt `docs/prompts/F2a_backend.md`, plan `docs/superpowers/plans/2026-10-13-f2a-backend.md` (sections + design decisions).
Supabase project: **skak, ref `ivznhyyaswhnpdrnnbno`** (the Supabase MCP in `.mcp.json` is pinned to it). Never touch another project.

| Section | Status |
|---|---|
| 1. Schema + RLS | **Done.** Local pgTAP green; applied to remote. |
| 2. apply_move + finish_game + make_move EF | **Done.** pgTAP green; migration applied to remote; `make_move` deployed (v1, verify_jwt on). |
| 3. RPCs (invite/queue/resign/draw/abort/timeout, set_profile) | **Done.** Applied to remote. `20261013000300_rpcs.sql`, `tests/03_rpcs.test.sql` (53 tests). |
| 3b. Advisor fixes | **Done.** Applied to remote. `20261013000400_advisor_fixes.sql`, `tests/04_advisor_fixes.test.sql`. |
| 4. pg_cron sweep + delete_account | **Done.** Applied to remote; `skak-sweep` runs every minute on skak (runs succeed); `delete_account` v1 deployed (verify_jwt on). |
| 4b. Invite expiry (sweep aborts invites waiting > 24 h, termination `expired`) | **Done locally, NOT applied remotely**: `20261016000100_expire_invites.sql`, `tests/06_invite_expiry.test.sql`. Adaam runs `npx supabase db push`. |
| 5. Concurrent matchmaking, smoke game, CI backend job, docs/ONLINE.md | **Done** (2026-10-16). |

**Next steps:** (1) Adaam: `npx supabase db push` (applies 4b), then rerun the advisors and check `select pg_get_functiondef('public.sweep_games()'::regprocedure)` mentions `expired`. (2) F2b: the app side, starting from `docs/ONLINE.md`.

**Section 5 notes:**
- `.gitattributes` forces LF for `.sql` and `.ts` (the working copies were CRLF on Windows, so CR characters got into function bodies pushed from this machine; the 0003–0005 functions on skak still contain them: harmless, they go away when a function is next replaced).
- Concurrent matchmaking: `supabase/integration/matchmaking_concurrency_test.ts` (Deno + `postgres` 3.4.9 against the local DB): 80 users over two time controls call `join_queue` at once on their own connections, twice. Asserts nobody is in two games, no self or cross-time-control pairing, everyone paired, the second call returns the player's game, queue empty. Fails 3/3 with the advisory lock removed. Cleans up its users and games.
- Smoke game: `supabase/scripts/smoke.ts`. Users `smoke_white@example.com` / `smoke_black@example.com` (usernames `smoke_white`, `smoke_black`) on skak, created through the Admin API; each run sets a fresh random password (nothing stored). Plays Fool's mate via invite + `make_move` with retry / wrong-turn / illegal / stale checks and an RLS check; aborts and re-invites until smoke_white gets White. Passed on skak twice (games a7cdd17e…, 82fcdf33…; ratings now smoke_black 1231, smoke_white 1169). Keys for a run: `npx supabase projects api-keys --project-ref ivznhyyaswhnpdrnnbno --reveal -o json` (without `--reveal` secret keys are masked) piped into env vars, never printed.
- `make_move` v3 (deployed to skak with the CLI): every response has `server_now` (ISO time) for the client's clock offset (ADR-0005 needed a server time in responses; nothing provided one). For RPC calls F2b can use the HTTP `Date` header.
- CI: new `backend` job (`npm ci` for the pinned Deno + Supabase CLI; `deno fmt --check`, `deno lint`, `deno test` for functions; `supabase db start`; `supabase test db`; concurrency test).
- `docs/ONLINE.md`: the contract for F2b (sequence, make_move + error codes, RPC table, Realtime/resync, clocks, results, rating, sweep, deletion, testing).
- Tests: pgTAP 135, Deno 39 (+1 integration), Flutter 255.
- Open: ADR-0004 asks to measure the Edge Function hop latency (cold start + warm) and report it in the README; not done yet (the smoke script is the natural place to time it).

**Remote applies:** the Supabase MCP's `apply_migration` returned `declined` for 0003 (twice, with no prompt shown; likely its confirmation for "destructive" SQL such as `delete from`, which this session cannot display). Adaam applied 0003–0005 with `npx supabase db push` and deployed both functions with the CLI on 2026-10-13. Verified afterwards: versions 0003/0004/0005 recorded; a fingerprint of every public function, index, constraint, column, grant and the cron job is identical to the local stack (the six section 2 functions differ only by CR characters: they went in through the MCP with LF, while the local stack loads the CRLF Windows checkout); both functions boot (`UNAUTHORIZED` for a non-user token); deployed `make_move` source = repo. Use `db push` for future migrations (it records versions itself; no renaming needed).

**Advisors after the apply (2026-10-13):** security: 11 × `authenticated_security_definer_function_executable`, one per player RPC (set_profile, create_invite, join_invite, join_queue, leave_queue, resign, offer/accept/decline_draw, abort, claim_timeout). Accepted, not a bug: by design (ADR-0004) tables are read-only and these RPCs are the only write path; each checks `auth.uid()`. All internal helpers are not executable by anon/authenticated. Performance: only `unused_index` (empty database), ignored.

**Section 4 notes (decisions):**
- `sweep_games()` (runs as postgres from pg_cron `skak-sweep`, `* * * * *`; no role can call it): settles games past the first-move deadline (abort, `firstMoveTimeout`) or with a flagged clock (timeout; draw when the winner has no mating material), with `FOR UPDATE SKIP LOCKED` so it never waits on a move in progress. Drops queue entries whose `seen_at` is older than 2 minutes.
- Queue heartbeat: `matchmaking_queue.seen_at` (added in the 0003 migration, which was not yet applied anywhere remote). Every `join_queue` call refreshes it; `created_at` keeps the place in line. F2b: the app re-calls `join_queue` while waiting (e.g. every 30 s).
- Account deletion policy (no ADR covered it; Adaam to confirm): `prepare_account_deletion(uid)` (service_role only) removes the queue entry, aborts waiting invites and games with fewer than 2 plies, resigns running games (rated, so the opponent keeps the win; a flag already due wins over the resignation). Then `delete_account` deletes the auth user: profile and own rating history go by cascade; games and moves stay for opponents with the player set to null. If the first step fails the account is kept (retry-safe).
- Advisors (2026-10-13, before 0003–0005): fixed `function_search_path_mutable` (first_move_seconds), `unindexed_foreign_keys` (games.draw_offer_by, moves.played_by: both ON DELETE SET NULL, scanned on account deletion), `no_primary_key` (rating_history now PK (game_id, user_id)). Ignored: `unused_index` (empty database).
- `_shared/admin.ts`: service-role client, `userIdFrom(req)`, `json()`, shared by both functions.
- Tests: pgTAP 131, Deno 39, Flutter 255 green.

**Section 3 notes (decisions):**
- RPCs: `set_profile(p_username, p_avatar)`, `create_invite`, `join_invite(code)`, `join_queue` (returns `setof games`: one row = paired, none = queued), `leave_queue`, `resign`, `offer_draw`, `accept_draw`, `decline_draw`, `abort`, `claim_timeout`. EXECUTE for `authenticated` only; helpers (`require_uid`, `check_time_control`, `random_invite_code`, `start_game`, `lock_my_game`) are internal.
- Game actions return the game. On a game that is already over they change nothing and return it (safe retries). Each settles the clock first, so a flag beats a late resign/draw.
- Usernames are set once (`USERNAME_LOCKED` after); names starting with `u_` are rejected (`BAD_USERNAME`) because they could clash with a future signup's temporary name and make that signup fail. Avatar key `^[a-z0-9_]{1,32}$`, changeable.
- `create_invite` returns the caller's existing waiting invite with the same time control instead of a second one. Codes: 6 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` via `gen_random_bytes` (pgcrypto, present on remote in `extensions`).
- `offer_draw` when the opponent already offered = agreement (Lichess). `abort` works while ply < 2, and the creator can cancel a waiting invite (termination `aborted`).
- `join_queue` returns the caller's active matchmaking game if there is one (that is how a queued player learns about the pairing), so one matchmaking game at a time.
- Mutation check: breaking the resign winner or the `u_` reservation makes the suite fail (tests 46–47, 12/14).

**Section 2 notes:**
- `make_move` = `functions/make_move/index.ts` (HTTP, `auth.getUser(token)`, service-role client from `SUPABASE_SECRET_KEYS.default`, fallback `SUPABASE_SERVICE_ROLE_KEY` locally) + `move.ts` (logic behind a `MoveDb` interface, unit-tested with a fake). Response `{game, applied}` or `{error}`: BAD_REQUEST 400, UNAUTHORIZED 401, NOT_A_PLAYER 403, NOT_FOUND 404, STALE/NOT_YOUR_TURN/GAME_OVER/DUPLICATE_MOVE_ID 409, ILLEGAL 422. A retry with a known `client_move_id` returns the current game with `applied: true`; `applied: false` with 200 = the mover's clock had run out (game ended on time).
- Deno setup: `supabase/functions/deno.json` (import map: chess.js 1.4.0, supabase-js 2, @std/assert; `nodeModulesDir: none` because the root package.json would otherwise force node_modules mode) + `deno.lock`. Run: `npx deno test --config supabase/functions/deno.json --allow-read supabase/functions/`. Also `deno lint` / `deno fmt` with the same config.
- Deploying with the MCP: files `index.ts`, `move.ts`, `../_shared/chess_rules.ts`, `deno.json` (without @std/assert), with LF line endings.
- Fixture `test/fixtures/tricky_positions.json` (20 positions, every legal move with SAN, FEN after, check/mate/stalemate, insufficient material per side) is produced by `test/online/tricky_positions_test.dart` from dartchess (`UPDATE_FIXTURES=1 flutter test test/online/tricky_positions_test.dart` regenerates it; otherwise the test checks the file is current). chess.js + `chess_rules.ts` match it exactly. The old generator failed because dartchess exports its own `File`, which clashes with `dart:io` (`hide File`).
- Tests: pgTAP 51, Deno 37, Flutter 255 green.

**How to run locally:** Docker Desktop on; `npx supabase start -x studio,imgproxy,storage-api,logflare,vector,mailpit,postgres-meta,supavisor`; `npx supabase test db`. Supabase CLI 2.120.0 and Deno 2.9.6 are pinned npm devDependencies (`npm install` first). Note: the CLI's SQL splitter choked on `if x <> case ... end then` inside plpgsql; avoid inline CASE in IF conditions.

**Remote migrations applied** (MCP `apply_migration`; its version is then renamed in `supabase_migrations.schema_migrations` to match the local file name, so `supabase db push` stays consistent):
- `20261013000100_schema` (2026-10-13)
- `20261013000200_apply_move` (2026-10-13; md5 of the stored statement matches the file, LF line endings)
- `20261013000300_rpcs`, `20261013000400_advisor_fixes`, `20261013000500_sweep_and_deletion` (2026-10-13, by Adaam with `npx supabase db push`; objects verified identical to the local stack)
- Pending: `20261016000100_expire_invites` (Adaam: `npx supabase db push`)

**Decisions so far:** termination strings use the Dart `Termination` names (`checkmate`, `timeout`, `resignation`, ... plus `agreement`, `firstMoveTimeout`); games store `white_can_mate`/`black_can_mate` (set by make_move) so timeouts in SQL need no chess code; clocks start after both first moves (30 s first-move deadline each, then abort); one advisory lock serialises matchmaking (planned). Details in the plan.

**Open:** `review_notifier_test` "checkmate position is scored without the engine" failed once in a full `flutter test` run and passed on rerun (flaky under load; not touched by F2a).

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
- 2026-10-13: Renamed Langkah → Skak (prompt `docs/prompts/rename_skak.md`). Dart package `skak`, `kAppName` "Skak" (wordmark, Android label), PGN Event/Site, app id/namespace `com.syafiyyy.skak` (old dev install uninstalled on the emulator; no data migration, dev data only), DB file `skak.db`. Docs, ADR-0001 note, skill `skak-design`. GitHub repo renamed to `Syafiyyy/skak-chess` (remote updated; description and topics set). Brand assets have no text, unchanged. Screenshots with the wordmark retaken (home, game ×3, game over); the others show no name. Release APK checked: label "Skak", package `com.syafiyyy.skak`. Also fixed a flaky test (revision bump now awaits `whenSaved()`).

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
1. Adaam: Google sign-in on a device with a Google account (emulator: Settings → add account, or a phone with a debug build from this machine). If it fails with a nonce error, turn on "Skip nonce checks".
2. Adaam: hand check of F2b (list in the hand-off message). Rerun the advisors after the 2026-10-17 push.
3. Then F3 — Polish (sounds/haptics, online empty/error states, Sentry, Maestro).
- Still open from before: F1.8b hand check and the Gate 1.5 demo clip.

## Environment
- Flutter 3.47.7 stable (D:\dev\flutter), Dart 3.13.5, JDK 21 (Android Studio jbr), Android SDK 36, licenses accepted (2026-10-12)
- Emulator: Pixel_8a_API_35 (system image android-35 google_apis_playstore x86_64 installed 2026-10-12). Other AVDs use the same image.
- GitHub: Syafiyyy/skak-chess (public; renamed from langkah-chess, GitHub redirects old links)
- Supabase project: `skak` (ref ivznhyyaswhnpdrnnbno, Singapore), created by Adaam 2026-10-13. Project-scoped Supabase MCP in `.mcp.json`.
