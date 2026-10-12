# ADR-0003: Supabase instead of Firebase
Status: Accepted (2026-10-12)

## Decision
Supabase (Auth, Postgres + RLS, Realtime, Edge Functions, pg_cron), region Singapore (ap-southeast-1), free tier.

## Why
- Moves need transactions and unique constraints for idempotency; Postgres gives both natively.
- Chess data is relational (games, moves, ratings).
- Adaam already knows Supabase + RLS; Supabase MCP is available to Claude.

## Trade-offs
- Free project pauses after 7 days idle → keep-alive cron in CI (F4).
- Free limits (500 MB DB, 200 concurrent Realtime connections, 500k Edge invocations/mo) are far above expected load (tens of users).
- Weaker offline cache than Firestore; offline play is engine-only anyway.
