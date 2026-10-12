# Prompt F1.8 — Design system + offline redesign (paste into a NEW Claude Code session)

Adaam approved the visual direction (mockups made in claude.ai). Goal: one fixed app look ("Songket" shell) + user-selectable board themes and piece sets, applied to every offline screen. Online screens (F2) will reuse this system, so the system matters more than any single screen.

## 0. Before coding
- Confirm Dart MCP + Context7 tools are loaded; if not, stop and tell me.
- Read `CLAUDE.md`, `docs/STATE.md`, ADR-0006, the `frontend-design` skill. If the vectorlab-ux-skills plugin is available, use its typography / spacing / colour-palette / motion / reduced-motion skills while building and run `ux-audit` at the end.
- Use superpowers `writing-plans` (no brainstorming: the direction is decided below). Show the plan, then continue.

## 1. The app shell (fixed, "Songket")
Tokens (put them in `lib/app/theme/`, replace the F0/F1 placeholders, no hard-coded colours in widgets):
- Ground `#101826`, surface `#18233A`, raised surface `#1F2C48`, border `#2C3B59`
- Text `#F3EEE3`, muted text `#AFB8C9`, faint text `#7D879B`
- Accent gold `#D9A93F` (hover/pressed `#EBC56B`); text on gold `#101826`
- Danger (resign, errors) — pick an accessible coral on navy; success for wins — pick an accessible green; check every text/background pair is >= 4.5:1 (3:1 for 24px+) and write the ratios in STATE.
- Review labels: best / inaccuracy / mistake / blunder colours that differ in lightness, not hue only.
- Type: Sora (600/700) for headings and the wordmark; Plus Jakarta Sans (400/500/700) for UI text; DM Mono (500) for clocks and move lists. **Bundle the font files as assets** (app is offline-first; no runtime font download). Define a small type scale (e.g. 12/13/15/17/20/24/32) and use only those.
- Spacing 4/8 scale; radii 8 / 10 / 14 / 999; elevation = borders + raised surface, no heavy shadows.
- Motion tokens (fast 120 ms, base 200 ms, slow 320 ms, one standard easing) via flutter_animate; respect reduced motion (`MediaQuery.disableAnimations`) with instant/opacity-only fallbacks.
- Icons: one consistent stroke icon set (pick one package or keep Material Symbols Rounded; no mixing).
- Wordmark: "Langkah" in Sora 700 with a small gold diamond mark (rhombus) before it.

## 2. Board themes + piece sets (user-selectable)
- `BoardTheme` model: id, name, light, dark, last-move light/dark, selected/premove/check highlight colours, frame style. Map to chessground's colour scheme API (check Context7).
  | id | light | dark | last light | last dark | frame |
  |---|---|---|---|---|---|
  | songket (default) | #EFE3C8 | #3F6E73 | #F2D688 | #7FA06A | 6px woven songket lattice: thin gold diagonals both ways on #18233A, drawn with a CustomPainter |
  | walnut | #E9CFA6 | #A9774A | #F0D98C | #C79A4E | 6px solid #3A2A1E |
  | graphite | #D8DEE6 | #6E7F92 | #DDF0A0 | #94AE5E | 6px solid #1E242E |
- Piece sets: offer 3–4 of chessground's bundled sets (default the cleanest one; check which sets exist).
- Persist both choices (existing key-value store), expose via Riverpod, and use them on EVERY board: game, review, history replay, PGN review, any thumbnails.
- Eval bar and eval graph colours follow the shell tokens (not the board theme).

## 3. Screens (apply the system; keep all behaviour and tests)
- **Home**: wordmark header; primary "Play vs Bot" card; "Resume game" banner when a saved game exists; History; Review a PGN (if present); Settings. Clean, generous spacing, no clutter.
- **New game sheet**: level picker shows names (Newcomer…Full strength) with short descriptions; colour, time control, bot speed; one gold primary button ("Start game").
- **Game screen** (match the approved mockup): top bar (back, wordmark, menu); bot bar (avatar tile, name, "Level n · Thinking…" with subtle animated dots, clock); board with theme frame; player bar with **gold active clock**; move list in DM Mono with the current move as a pill; bottom row of 4 labelled buttons (Takeback, Flip, Moves, Resign) in surface tiles, 60 px tall.
- **Game-over sheet**, **Abandon dialog**: same tokens; destructive actions named ("Resign game", "Abandon game").
- **History** list + **Replay**; **Review** screen (eval bar, graph, labels, summary card) restyled with tokens.
- **Settings** (new): Board theme (live preview board + 3 theme cards, selected = gold border + check), Piece set, Bot speed default. Reachable from Home and the game menu.
- Small screens: no overflow at 360 dp width; touch targets >= 48 dp.

## 4. Brand assets
- App launcher icon: gold rhombus mark on navy (adaptive icon for Android). Use `flutter_launcher_icons`.
- Native splash: navy background + mark, no fake delay (`flutter_native_splash`).
- App label stays "Langkah" (from `kAppName`).

## 5. Make it stick for later phases
- Create `.claude/skills/langkah-design/SKILL.md`: tokens, type scale, spacing, components (player bar, clock, tile button, card, sheet, dialog), board theme rules, motion + reduced-motion rules, accessibility rules, "never hard-code colours". Update `CLAUDE.md` to load it for any UI work.
- Shared widgets in `lib/shared/widgets/` (TileButton, PlayerBar, ClockChip, SectionCard, AppSheet, ConfirmDialog, BoardFrame).

## 6. Tests + finish
- Keep all existing tests green; add widget tests for Settings (theme switch persists and changes the board scheme) and golden tests for Home, Game, Review at 390x844 (store goldens in repo).
- Save screenshots of Home, Game (each of the 3 board themes), Review, Settings to `docs/screenshots/` (for README/portfolio).
- Update `docs/STATE.md` (decisions, contrast ratios, known issues). Commit in logical steps, push, CI green.
- Give me a short hand-check list and tell me which screenshots to use for the portfolio.
