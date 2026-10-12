# F1.8 Design System + Offline Redesign — Plan

> Executed inline. Spec: `docs/prompts/F1_8_design.md` (direction approved by Adaam; no brainstorming).

**Goal:** one fixed "Songket" app shell + user-selectable board themes and piece sets on every board, applied to all offline screens, captured in a `langkah-design` skill for F2.

## Tasks
1. **Fonts + tokens (TDD for contrast).** Bundle Sora 600/700, Plus Jakarta Sans 400/500/700 (static instances made from the Google Fonts variable files with fontTools) and DM Mono 500, with OFL licences. Rewrite `lib/app/theme/`: colours (Songket palette + accessible danger/success + review label colours that differ in lightness), type scale 12/13/15/17/20/24/32, spacing 4/8, radii 8/10/14/999, motion tokens + reduced-motion helper. Unit test: WCAG contrast of every text/background pair (>= 4.5:1, >= 3:1 for >= 24 px).
2. **Board themes + piece sets (TDD).** `BoardTheme` (songket default, walnut, graphite) → chessground `ChessboardColorScheme`; last-move overlay solved so it lands near both target colours. Piece sets: cburnett (default), merida, california, staunty. Prefs persisted in the kv store, exposed via Riverpod. `BoardFrame` (songket lattice CustomPainter / solid frames). Used by game, review and replay boards.
3. **Shared widgets.** Wordmark, TileButton, PlayerBar, ClockChip, SectionCard, AppSheet, ConfirmDialog, BoardFrame in `lib/shared/widgets/`.
4. **Screens.** Home, new game sheet (level names + descriptions, bot speed), game screen (top bar with menu, bot bar with thinking dots, framed board, gold active clock, DM Mono move list with pill, 4 × 60 px tiles: Takeback / Flip / Moves / Resign), game-over sheet, abandon + resign dialogs (named destructive actions), history, replay, review, new Settings screen (live preview, theme cards, piece set, bot speed default). 360 dp, 48 dp targets.
5. **Brand.** Launcher icon (adaptive, gold rhombus on navy) via flutter_launcher_icons; native splash via flutter_native_splash (no delay).
6. **Make it stick.** `.claude/skills/langkah-design/SKILL.md`; CLAUDE.md loads it for UI work.
7. **Tests + finish.** Existing tests green; Settings widget test (theme persists, board scheme changes); goldens Home / Game / Review at 390×844 (in repo, small tolerance for cross-platform AA); emulator screenshots to `docs/screenshots/`; vectorlab `ux-audit`; STATE (contrast ratios); commits, push, CI.
