# Roadmap

Scope rule: finish the minimum impressive version first. Extras only when a gate passes with time left.

## F0 — Foundation
- New repo `Syafiyyy/langkah-chess` (public, GPL-3.0)
- Flutter >= 3.29 (latest stable), Android only
- Dart & Flutter MCP server + Context7 configured for Claude Code
- Skills: karpathy-rules, frontend-design, chess-domain
- Feature-first structure, Riverpod, go_router, lints
- CI (GitHub Actions): analyze + test + build split APK
- Smoke test: chessground board shows start position; EngineService returns a bestmove from multistockfish (light)

## F1 — Core offline
- Play vs engine with Elo levels (UCI_LimitStrength + UCI_Elo), choose colour
- Clock + increment, resign, draw rules (stalemate, repetition, 50-move, insufficient material, timeout-vs-insufficient-material)
- Move list, takeback vs AI, flip board, promotion picker
- Local game history (stored on device), replay, PGN export/share
- Minimal design tokens + theme (dark-first)
- Unit tests: game controller, clock, result rules

**Gate 1:** a full game vs AI is smooth, no engine leaks, tests green. (No Android phone available: Gate 1 is checked on the emulator; real-phone timing moves to F4 via Firebase Test Lab.)

## F1.5 — Game Review (main "wow" feature)
- Analyse a finished game with the engine (background, cancellable)
- Eval bar + eval graph (fl_chart)
- Move labels: best / good / inaccuracy / mistake / blunder; accuracy % per side
- Show engine best move with arrow on the board

**Gate 1.5:** demo-worthy offline app. Record a short clip.

## F1.8 — Design system + offline redesign
- Fixed "Songket" app shell (navy + gold, Sora / Plus Jakarta Sans / DM Mono), tokens + `langkah-design` skill
- Selectable board themes (Songket default, Walnut, Graphite) and piece sets, used by every board
- Redesign Home, New game, Game, Game-over, History, Replay, Review; new Settings screen; app icon + splash
- (Decision 2026-10-12: design before online so F2 screens reuse the system.)

## F2 — Online
- Supabase project (region Singapore), Auth: email + Google (SHA-1 debug + release)
- Schema + RLS: profiles, games, moves, rating_history, matchmaking queue
- Play friend via invite code / deep link; simple matchmaking (queue, cancel, timeout)
- Edge Function `make_move` validates with chess.js, then calls Postgres `apply_move()` (atomic, idempotent)
- Server clock (server-time offset on client), abandon/first-move deadline sweep (pg_cron)
- Realtime = hint only; resync on reconnect/resume
- Elo rating with history (idempotent per game), rematch
- SQL tests for apply_move + RLS; shared tricky-positions test file (dartchess vs chess.js)
- Account deletion flow

**Gate 2:** two emulators; kill network mid-game; background app 60 s; retry moves → no lost or duplicated move, clocks correct.

## F3 — Polish
- Apply the design system to online screens, sound + haptics, final motion pass
- Empty/error/loading states, reconnecting banner, opponent-left flow
- Sentry (free) for crashes; one Maestro smoke flow

## F4 — Ship
- README: architecture diagram, ADR links, measured move latency, screenshots
- 90-second demo video
- Real arm64 phone check: run the on-device integration tests (bot games, review) on Firebase Test Lab physical devices (free daily quota); record timings in README
- Signed release APK on GitHub Releases
- GitHub Actions cron to keep the Supabase free project from pausing
- Add to portfolio site + resume + GitHub profile README

## If time allows (pick one at a time)
- Puzzles (import 20–50k from the Lichess CC0 puzzle DB)
- AI Coach (Gemini via Edge Function, daily limit per user)
- Glicko-2, Chess960, correspondence games, spectating, Maia bots
