# Prompt F2b — Online in the app (NEW Claude Code session, after F2a is done)

Goal: play online from the app against a real person, robust to bad mobile networks. Use the existing design system (`skak-design` skill) for every new screen.

## 0. Before coding
- Confirm Dart MCP, Context7, Supabase MCP are loaded. Read `CLAUDE.md`, `docs/STATE.md`, `docs/ONLINE.md`, ADR-0004/0005, chess-domain + skak-design skills. `writing-plans` first; TDD for the online game controller and resync logic.

## 1. Auth + profile
- `supabase_flutter`; URL + anon key from `--dart-define-from-file`.
- Sign in with email + password and with Google (native Google Sign-In → `signInWithIdToken`). Tell me exactly what I must set up in Google Cloud (Android OAuth client with debug AND release SHA-1, web client ID for Supabase) and in the Supabase Auth settings; wait for me where needed.
- First login → choose username screen (validation on blur, availability check). Profile screen: username, rating, games, sign out, delete account (named confirmation, calls `delete_account`).
- Offline play must keep working with no account and no network.

## 2. Online entry points (Home → "Play online")
- Create invite: pick time control → shows the code big + Share (share_plus) + `skak://join/CODE` link (custom scheme; no domain needed) → waiting screen with cancel.
- Join with code: input field (6 chars, auto-uppercase), and opening a `skak://join/CODE` link.
- Quick match: pick time control → searching screen with elapsed time and cancel (calls `leave_queue`).

## 3. Online game screen (reuse the offline game UI components)
- Moves: optimistic local move with dartchess → `make_move` with a `client_move_id` generated once per attempt and reused on retry (exponential backoff, max ~5 tries); on STALE/ILLEGAL → resync and roll back with a short, non-blaming message.
- Realtime subscription on the game row = hint only. On subscribe, reconnect, app resume and every hint: fetch the game + moves after the last known ply and rebuild. Server state always wins.
- Clocks: server clocks minus elapsed since `last_move_at`, corrected with a server-time offset measured from responses. Claim timeout when the opponent's clock hits zero.
- Connection banner: "Reconnecting…" when the channel or requests fail; never block the board for a single failed request.
- Controls: resign (confirm), offer/accept/decline draw, abort (only before both moved), rematch offer after the game (new invite between the same players).
- Opponent left / abandoned (server sweep) shows a clear result. Game over sheet reuses the offline one + rating change (+12 / −12).
- Online games appear in History (from the server, cached locally) and can be Reviewed with the existing Review feature.

## 4. Gate 2 test (do it and report)
- Two emulators (or emulator + second instance) signed in as two test users: full invite game and a quick-match game.
- Kill network on one device mid-game for 20 s, make a move during the outage, restore → move delivered exactly once, both boards identical.
- Background one app for 60 s → resume → board and clocks correct.
- Double-tap a move fast / retry → no duplicate move (check `moves` table).
- Let a clock run out → timeout result on both devices; ratings change once.
- Record results in STATE (Gate 2 checklist) with any measured move round-trip latency (median/max).

## 5. Finish
- Tests green, CI green, STATE updated, commit in logical steps, push. Give me a hand-check list and what I must configure by hand.
