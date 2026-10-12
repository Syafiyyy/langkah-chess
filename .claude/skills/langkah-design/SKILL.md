---
name: langkah-design
description: Langkah's "Songket" design system. Use for ANY UI work (new screens, restyles, widgets, online F2 screens): tokens, type scale, spacing, components, board themes, motion, accessibility. Never hard-code colours or text styles.
---

# Langkah design system ("Songket")

One fixed app look (navy + cream + gold) and user-selectable board themes. Tokens live in `lib/app/theme/`; shared components in `lib/shared/widgets/`. Reuse them; add a token or component instead of a one-off.

## Tokens (`lib/app/theme/`)
- **Colours (`AppColors`)**: `ground` #101826 (L0 canvas) → `surface` #18233A (L1 cards, lists, sheets) → `surfaceRaised` #1F2C48 (L2 dialogs, selected tiles, chips) + `border` #2C3B59 (1 px). Text `text` #F3EEE3, `textMuted` #AFB8C9. `textFaint` #7D879B is **disabled/decor only** (4.34:1 on surface). Accent `accent` #D9A93F, pressed `accentPressed` #EBC56B, text on gold `onAccent` #101826. `danger` #FF7B6E (resign, errors, low clock), `success` #5ED39A (wins). Review labels `labelBest` / `labelInaccuracy` / `labelMistake` / `labelBlunder` step down in lightness (L* 80 / 86 / 71 / 64), never hue only. `evalWhite` / `evalBlack` for the eval bar and graph (shell colours, not the board theme).
- **Contrast**: every text/background pair is in `test/app/theme/contrast_test.dart` (>= 4.5:1). Adding a colour = adding it there.
- **Type (`AppType`)**: sizes 12/13/15/17/20/24/32 only. Sora 600 for `headline` (32), `title` (24), `heading` (20); Sora 700 only for `wordmark`. Plus Jakarta Sans: `subtitle` 17/500, `body` 15/400, `label` 15/500 (buttons), `secondary` 13/400 muted, `meta` 12/500 muted (timestamps, tile captions, hints only), `stat` 24/700 (summary numbers only). DM Mono 500: `move` 15 (move lists), `clock` 24 (tabular figures). Line height: headings 1.2, body 1.5, meta 1.4. Fonts are bundled in `assets/fonts` (offline-first; never download fonts at runtime).
- **Spacing (`AppSpacing`)**: 4 / 8 / 12 / 16 / 24 / 32. Screen padding 16; sheet padding 24; group gaps 8, section gaps 24.
- **Radius (`AppRadius`)**: `sm` 8 (chips, clock), `md` 10 (buttons, tiles), `lg` 14 (cards, sheets, dialogs), `pill` 999 (current move).
- **Elevation**: border + one surface step. No heavy shadows, no glows.
- **Icons**: Material rounded set only (`Icons.*_rounded`). Do not mix icon families.

## Components (`lib/shared/widgets/`)
- `Wordmark` / `DiamondMark`: gold rhombus + "Langkah" (Sora 700). App bars of top-level screens.
- `TileButton`: 60 px surface tile, icon over meta label; `destructive` uses `danger`. Game controls row of four.
- `PlayerBar`: avatar tile (bot/person glyph; gold side-to-move dot via `toMove`), name, subtitle or `ThinkingDots`, optional clock. Height 48. Bot bar: persona name, "Level n · Bot" subtitle.
- `ClockChip`: gold when running (`onAccent` digits), raised surface when idle, danger when low.
- `SectionCard`: L1 card (1 px border, radius 14), tappable; `selected` = 2 px gold border (+ a check icon in the content).
- `showAppSheet`: bottom sheet sized to content, scrolls, title in `title` style.
- `showConfirmDialog`: confirm button names the action ("Resign game", "Abandon game"); `destructive` colours it danger. Never "OK".
- `MoveList`: DM Mono strip, rounded L1 card on the 16 px gutter (full width); current move is a compact 28 px pill (gold fill, navy text) inside a 48 dp tap row; error marks (?! ? ??) coloured by label (navy on the pill).
- `ResultBadge` (`features/history/presentation`): W/L/D tile, success/danger/muted border; used by History and Home recent games.
- Layout: on board screens the bars/board (or board/verdict/graph) form one block with 8 px gaps; leftover height is split above and below, never left as a band.
- `BoardFrame` / `ThemedBoard`: every board goes through these (or `GameBoard` for play) so the theme, piece set and frame apply everywhere.

## Board themes (`lib/core/board/`)
- `BoardTheme`: songket (default; woven gold-lattice frame drawn by `BoardFrame`), walnut, graphite (solid frames). `colorScheme` maps to chessground. chessground has one last-move colour, so each theme stores a translucent overlay solved to land near both target colours.
- `PieceChoice`: cburnett (default), merida, california, staunty.
- `boardPrefsProvider` holds the choice (kv store keys `board.theme`, `board.pieces`). **Every board must read it**: game, review, replay, settings preview, any thumbnail.

## Motion (`AppMotion`)
- Durations `fast` 120 ms, `base` 200 ms, `slow` 320 ms; one curve `easeOutCubic` (flutter_animate for sequences).
- Animate opacity and transform only. No bounce/elastic, no decorative loops (the thinking dots are a functional loop).
- Reduced motion: `AppMotion.of(context, d)` returns zero when `MediaQuery.disableAnimations` is set; `AppMotion.reduced(context)` for widgets to switch to static (e.g. ThinkingDots shows plain "Thinking…"). Meaning never depends on motion alone.

## Accessibility rules
- Text >= 4.5:1 (3:1 only for >= 24 px), checked in `contrast_test.dart`.
- Touch targets >= 48 dp (theme sets 48 px minimum on buttons; tiles are 60).
- No overflow at 360 dp width: every screen has a 360 dp widget test.
- Selected states use border + icon/text, not colour alone. Results use letters (W/L/D) as well as colour.
- Interactive custom widgets get `Semantics` (button, selected, label).

## Never
- Hard-code colours, font sizes or radii in widgets (use tokens; add one if missing).
- Use `textFaint` for readable text, weights other than the ones above, or sizes off the scale.
- Build a board without `BoardFrame`/`ThemedBoard`/`GameBoard`.
- Use generic button labels ("OK", "Submit"); name the action.
