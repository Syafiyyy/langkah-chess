# ADR-0001: Rebuild from scratch, v1 as reference only
Status: Accepted (2026-10-12)

## Context
v1 (`uptm-chess-game`, Flutter + Firebase, Apr 2025) works partly but has structural problems: 1.3k-line god files mixing UI/Firebase/logic, Stockfish stdout listeners stacking every move, fragile online sync, Firestore rules not matching collection names, history saved twice, rating never persisted, duplicate Android gradle files, outdated packages.

## Decision
Start a new project and repo (`langkah-chess`). Use v1 only as a feature and content reference (see `docs/REFERENCE-V1.md`). Archive the v1 repo and link it from the new README as "v1".

## Consequences
+ Clean architecture and history; nothing inherited from the Firebase design.
+ "Revived and re-engineered" is a good portfolio story.
- Every feature is rewritten; nothing is reused except content (tutorial text, avatars).
