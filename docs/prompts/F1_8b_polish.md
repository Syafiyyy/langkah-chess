# Prompt F1.8b — Design polish from screenshot review (NEW Claude Code session)

Read `CLAUDE.md`, `docs/STATE.md`, `.claude/skills/langkah-design/SKILL.md`. Use the frontend-design skill and vectorlab ux skills (spacing, typography, empty-states, anti-slop). Small, focused pass; keep all tests green and update goldens + `docs/screenshots/` after.

Review of `docs/screenshots/` (by Adaam's planner):

## Game screen (game_songket.png)
1. Vertical rhythm is off: ~120 px dead gap between the top bar and the bot bar, and ~180 px between the player bar and the move list. Group bot bar + board + player bar as one block that hugs together (8–12 px gaps), and place the block so leftover space is balanced (e.g. centred between top bar and the move list/controls), not dumped in two random gaps. Must still fit 360 dp wide / small heights without overflow.
2. Current-move indicator in the move list renders as a large gold-outlined CIRCLE that is clipped at the edge. Make it a compact pill (radius 999, horizontal padding, same height as the other move items; raised-surface fill + gold text, or gold fill + navy text) and auto-scroll so it's never clipped. Keep the 48 dp tap target via padding/hit area, not visual size.
3. Move-list band and bottom tiles use a different side inset (~12 px) than the rest (16 px). Align to the same 16 px gutter.
4. The small hollow/white circles on the avatar corners look like unfinished "online presence" dots. Offline they mean nothing: remove them, OR turn them into a clear side-to-move indicator (gold dot on the player whose turn it is). Pick one and document it.
5. Bot bar title: show the persona as the name ("Beginner") with "Level 2 · Bot" as the subtitle (matches the approved mockup), instead of "Bot" / "Level 2 · Beginner".

## Review screen (review.png)
6. Accuracy card counts "1?! 0? 0??" are hard to read. Use small labelled chips per side ("1 Inaccuracy", "0 Mistakes", "0 Blunders") with their label colour dot; dim or hide zero counts.
7. Large empty bands above and below the board. Tighten: summary card → board with eval bar → verdict line → graph, consistent spacing; give the eval graph more height (~120–140 px) and a visible midline so swings and mistake markers read clearly.
8. Make sure the review board uses the user's chosen board theme (the screenshot shows Graphite while Settings shows Songket — confirm whether that was just a different capture or a bug; if a bug, fix and add a test).

## Home (home.png)
9. The lower half is empty. Add a "Recent games" section (last 3: bot level, result chip, accuracy if reviewed, date; tap → replay/review; empty state pointing to "Play vs Bot") and a slim stats row (games played · wins · best accuracy). Local history only.
10. Settings appears twice (top-right icon and the card). Keep one entry point (keep the card).

## Finish
- Re-run ux-audit on the changed screens. Update goldens and `docs/screenshots/` (same file names). Update STATE.md, commit in logical steps (include this prompt file), push, CI green. Give me a 5-item hand check.
