# ADR-0002: Lichess chess stack, project licensed GPL-3.0
Status: Accepted (2026-10-12)

## Context
v1 used `squares` + `bishop` + `stockfish` 1.7.1. Stockfish is GPL-3.0, so any app that ships it is already bound by GPL-3.0.

## Decision
- Board UI: `chessground` (lichess-org, GPL-3.0; needs Flutter >= 3.29)
- Rules/FEN/SAN/PGN: `dartchess` (lichess-org, GPL-3.0)
- Engine: `multistockfish` (lichess-org; Stockfish 19), **light flavor** (~1 MB embedded NNUE), wrapped in one `EngineService`
- Repo license: GPL-3.0, public

## Consequences
+ Same stack as the Lichess mobile app: maintained, fast, polished.
+ Newest Stockfish, no external NNUE download for the light flavor.
- One live engine per flavor; engine isolates must be disposed before hot reload.
- Lichess pins some packages to git refs; we use the published pub.dev versions only. Verify versions before pinning.
- Code must stay open source (fine for a portfolio project).
