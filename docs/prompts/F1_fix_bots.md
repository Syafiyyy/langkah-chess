# Prompt F1-fix — Human-like bots (run BEFORE F1.5, in a NEW Claude Code session)

Gate 1 hand test (emulator) result from Adaam: everything works, BUT
1. Level 1 (labelled ~800) is far too strong; a casual player loses every game. Stockfish `Skill Level 0` + depth 1 does not play like an 800 human (it rarely hangs pieces or misses simple tactics).
2. The bot moves instantly; it feels robotic. It should look like it is thinking.
3. Promotion was not tested by hand (the bot was too strong to reach it). Make sure the promotion widget test exists and passes.

Read `CLAUDE.md`, `docs/STATE.md`, `.claude/skills/chess-domain/SKILL.md`, `lib/features/play_ai/domain/bot_level.dart`. Use superpowers `test-driven-development` for the move-selection logic.

## 1. Human-like move selection for the weak levels
- Levels 1–4 no longer play Stockfish's bestmove directly. Instead:
  - Ask the engine for several candidate moves: `setoption name MultiPV value N` (e.g. 6–10) at a low depth/movetime. Extend the UCI parser/EngineService to collect `info ... multipv k ... score ... pv ...` lines into a candidate list (best move per multipv index, latest depth wins). Reset MultiPV to 1 for normal search and for analysis.
  - Pick a move from the candidates with a level-dependent policy, e.g. softmax over win% with a temperature per level, plus a per-level "blunder chance" where the bot picks a clearly worse candidate or (level 1 only) occasionally a random legal move.
  - Guardrails so it still feels like chess: never pick an illegal move; level 1–2 may miss a mate-in-1 sometimes, level 3–4 almost never; no suicidal queen giveaway every move (cap how often big blunders happen in a row).
- Put the policy in pure Dart (`features/play_ai/domain/`), with an injectable random seed so tests are deterministic.
- New level scale (Adaam's decision): level 1 must feel like someone who JUST learned the moves, well below 800.
  | Level | Feel | Approx label |
  |---|---|---|
  | 1 | Newcomer: knows the rules, often hangs pieces, misses free captures, never sees mate threats | ~300 |
  | 2 | Beginner: grabs free pieces, still blunders often | ~550 |
  | 3 | Casual: avoids most one-move blunders, misses tactics | ~800 |
  | 4 | Improving: decent moves, occasional mistakes | ~1100 |
  | 5 | Club (UCI_Elo ~1400) | ~1400 |
  | 6 | Strong club (UCI_Elo ~1800) | ~1800 |
  | 7 | Expert (UCI_Elo ~2200) | ~2200 |
  | 8 | Full strength | Max |
- Levels 1–4 use the candidate-selection policy above (level 1 the most random). Levels 5–8 use UCI_Elo / full strength.
- Labels are approximate; show "Level n · Newcomer" style names, with the rating only as a hint.

## 2. Calibration (evidence, not guesses)
- Write an on-device/integration calibration test: bot level N vs level N+1, ~10 games each pair at short think time; record score. Target: the higher level wins roughly 65–80%. Also: level 1 vs a "random legal move" player should win, but not instantly.
- Adjust temperatures / blunder chances until the curve is monotonic. Put the final table + results in `docs/STATE.md`. Relabel approximate ratings honestly (e.g. "Beginner", "Casual", "Club") if numbers can't be justified.

## 3. Natural thinking time
- The bot waits a human-like time before moving: base delay per level + random spread + longer in complex positions (e.g. more legal moves / captures available / check), shorter for forced or recapture moves. Roughly 0.6–2.5 s for low levels; higher levels use their real search time and only pad up to a minimum.
- In timed games, the delay counts against the bot's clock (it's realistic) and never risks flagging: cap it by the existing safe-fraction rule.
- Show a subtle "thinking" indicator on the bot's player bar.
- Setting on the new-game sheet: Bot speed "Natural" (default) / "Fast". Remembered with the other choices.
- Takeback/resign/leaving the screen cancels the pending delay and search immediately.

## 4. Update the chess-domain skill
Add a short "Bot behaviour" section: candidate selection rules, MultiPV reset rule, thinking-delay rule, calibration requirement.

## 5. Finish
- Tests green, CI green, commit in logical steps, push.
- Update `docs/STATE.md`: calibration table, decisions, Gate 1 status ("passed on emulator after bot fix; real-phone timing pending, F4 Firebase Test Lab").
- Give me a 5-item hand-check: level 1 beatable and makes visible mistakes, thinking delay feels natural, Fast mode works, promotion works (I'll try to reach it now), higher levels feel stronger step by step.
