# Skak — Claude Code instructions

Skak is a Flutter chess app (Android first) by Adaam (GitHub: Syafiyyy). It is a full rebuild of the old app `uptm-chess-game` (v1), which is reference only. (Formerly "Langkah"; renamed 2026-10-13. The local folder `D:\Projects\langkah-chess` keeps its old name on purpose: Claude Code's local plugins and MCP config are tied to that path.)

## Read first, every session
1. `docs/STATE.md` (current phase, what's done, what's next). This is the single source of state.
2. `docs/ROADMAP.md` (phases and gates).
3. `docs/adr/` (decisions). Don't contradict an ADR; if one seems wrong, stop and say so instead.
4. Skills in `.claude/skills/`:
   - `karpathy-rules`: always
   - `chess-domain`: any chess, engine, game or online code
   - `skak-design`: any UI work (tokens, components, board themes; never hard-code colours)
   - `frontend-design`: any UI work (after `skak-design`, which wins on conflicts)

## Hard rules
- Stack is fixed by ADRs: chessground + dartchess + multistockfish (light flavor) + Riverpod + go_router + Supabase. No Firebase. No `squares`, `bishop` or `stockfish` packages.
- Use Context7 / the Dart MCP server to check current package APIs before writing code. Don't rely on memory for package APIs.
- **multistockfish:** follow the package's current pub.dev docs and example (`Stockfish.create()`, flavors, `dispose()`). The repo ROOT README of lichess-org/dart-multistockfish describes an OLD API (`Stockfish.instance`, SF16): ignore it.
- The online client never writes to `games` or `moves` tables directly. All game mutations go through the server (see ADR-0004).
- Secrets (Gemini key, Supabase service role) never go into the app or the repo.
- Keep files small: one widget/screen per file, no god providers. If a file passes ~300 lines, split it.
- Ask Adaam before anything irreversible (deleting, archiving repos, force-push, paid services).

## Commands
- `flutter analyze` and `flutter test` must pass before every commit.
- Build: `flutter build apk --split-per-abi --release`

## End of every task
Update `docs/STATE.md`: what changed, decisions made, known issues, next step. Commit with a clear message.
