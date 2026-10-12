# ADR-0007: Elo first; APK on GitHub Releases
Status: Accepted (2026-10-12)

## Decision
- Rating: Elo (K=32 under 30 games, then 20) computed inside `apply_move`'s game-finish path; `rating_history.game_id` UNIQUE so it applies once. Glicko-2 is a later option.
- Distribution: signed split-per-ABI release APKs on GitHub Releases. Play Store is optional and not on the critical path (paid developer account + testing requirements).

## Consequences
+ Simple, correct, idempotent rating.
+ Anyone can install the demo from the repo.
