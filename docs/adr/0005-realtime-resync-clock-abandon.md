# ADR-0005: Realtime as a hint, resync, server clocks, abandon sweep
Status: Accepted (2026-10-12)

## Decision
- Realtime (postgres_changes on `games`, RLS-protected so only the two players can read) is only a "something changed" signal.
- On subscribe, reconnect and app resume: fetch the game row + moves after the last known ply. Server state always wins.
- Clocks: server stores `white_ms`, `black_ms`, `last_move_at`. Client displays a countdown using a server-time offset from responses.
- Timeout: client may claim it (fast path); server verifies. Timeout is a draw if the side NOT out of time has insufficient mating material (custom rule, unit-tested).
- `pg_cron` sweep every minute: first-move deadline, flagged clocks, stale matchmaking entries.

## Consequences
+ Survives dropped sockets, backgrounding and flaky mobile networks.
- More states for the UI (reconnecting, opponent left), handled in F2/F3.
