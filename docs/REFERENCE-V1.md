# v1 reference (uptm-chess-game)

Location on Adaam's PC: `C:\Users\AdamSyafi\Desktop\Adam\sem 6\uptm_chess` (GitHub: Syafiyyy/uptm-chess-game, last commit 2025-04-16). Read only. Don't copy code; copy ideas and content.

## Features in v1 (to carry over or replace)
| v1 feature | Langkah plan |
|---|---|
| Email/password, Google, guest login | Supabase Auth email + Google (F2); offline play needs no account |
| Play vs Stockfish (Easy/Medium/Hard) + choose time + colour | Elo levels (F1) |
| Online auto-matchmaking (availableGames → runningGames) | Invite code + simple queue, server-authoritative (F2) |
| Resign, timers, game-over dialog | F1 (offline), F2 (online) |
| Game history + filters (win/loss/draw/AI/online) | Local history F1, online history F2 |
| Profile, edit profile, SVG avatars (`assets/avatars/`), username change | F2 (reuse avatar SVGs) |
| Friends (requests) | Dropped for now; invite code covers playing friends |
| Tutorial screen (`lib/main_screens/menu_screen.dart`: basics, pieces, special moves, strategy, phases, time controls) | Reuse the text content later (F3) |
| Tournament screen | Was a placeholder; dropped |
| Settings screen | Was empty; build properly in F3 |

## v1 bugs to NOT repeat
- Stockfish `stdout.listen` added on every move → stacked listeners, duplicate engine moves.
- First AI move (when player is black) ignored difficulty.
- `whitesMove` / `blacksMove` never updated → online sync relied on illegal-move rejection.
- `FieldValue.arrayUnion` for move list dropped repeated identical moves.
- Game history written twice per game (listener + dialog button).
- Rating +10/-8 shown but never saved.
- Timeout always awarded the win, even with insufficient material.
- Security rules did not match collection names (`runningGames`, `game_history`).
- "Already running" timestamp hack in main.dart to dodge the single-engine limit.
- Fake 2-second splash delay.
- Both `build.gradle` and `build.gradle.kts` in android/app.
