// Concurrent matchmaking against the LOCAL stack (`npx supabase start` or
// `db start`): every user calls join_queue at the same moment, on its own
// connection, as `authenticated` with its own JWT claims. Nobody may end up
// in two games, every game pairs two different users with the same time
// control, and everyone gets paired. Uses throwaway users that are removed
// afterwards. Run:
//   npx deno test --config supabase/functions/deno.json --allow-net --allow-env \
//     supabase/integration/
import { assert, assertEquals } from "@std/assert";
import postgres from "postgres";

const DB_URL = Deno.env.get("SKAK_LOCAL_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const USERS = 40; // per time control
const CONTROLS = [[180000, 0], [300000, 2000]] as const;

type Game = { id: string; white_id: string; black_id: string; time_base_ms: number };

Deno.test("concurrent join_queue never pairs anyone twice", async () => {
  const sql = postgres(DB_URL, { max: USERS * CONTROLS.length, onnotice: () => {} });
  const players = CONTROLS.flatMap(([base, inc], c) =>
    Array.from({ length: USERS }, (_, i) => ({
      id: crypto.randomUUID(),
      email: `mm-${c}-${i}-${crypto.randomUUID()}@concurrency.test`,
      base,
      inc,
    }))
  );
  await sql`insert into auth.users ${sql(players.map(({ id, email }) => ({ id, email })))}`;

  const joinQueue = (p: (typeof players)[number]) =>
    sql.begin(async (tx) => {
      await tx`set local role authenticated`;
      await tx`select set_config('request.jwt.claims', ${JSON.stringify({ sub: p.id })}, true)`;
      const rows = await tx`select * from public.join_queue(${p.base}, ${p.inc})`;
      return (rows[0] as Game | undefined) ?? null;
    });

  try {
    // Round 1: everyone at once. Round 2: everyone again (heartbeat / "am I
    // paired yet?"). Shuffled so arrival order differs between rounds.
    const shuffled = () => [...players].sort(() => Math.random() - 0.5);
    await Promise.all(shuffled().map(joinQueue));
    const round2 = new Map<string, Game | null>();
    await Promise.all(shuffled().map(async (p) => round2.set(p.id, await joinQueue(p))));

    const ids = players.map((p) => p.id);
    const games = await sql<Game[]>`
      select id, white_id, black_id, time_base_ms from public.games
      where mode = 'matchmaking' and (white_id = any(${ids}) or black_id = any(${ids}))`;

    const seen = new Map<string, string>();
    for (const g of games) {
      assert(g.white_id !== g.black_id, `game ${g.id} pairs a user with themselves`);
      for (const u of [g.white_id, g.black_id]) {
        assert(!seen.has(u), `user ${u} is in games ${seen.get(u)} and ${g.id}`);
        seen.set(u, g.id);
        const player = players.find((p) => p.id === u)!;
        assertEquals(g.time_base_ms, player.base, "paired across time controls");
      }
    }
    assertEquals(games.length, players.length / 2, "everyone is paired");
    for (const p of players) {
      assertEquals(round2.get(p.id)?.id, seen.get(p.id), "join_queue returns the player's game");
    }
    const [{ queued }] = await sql`
      select count(*)::int as queued from public.matchmaking_queue where user_id = any(${ids})`;
    assertEquals(queued, 0, "the queue is empty");
  } finally {
    const ids = players.map((p) => p.id);
    await sql`delete from public.games where white_id = any(${ids}) or black_id = any(${ids})`;
    await sql`delete from auth.users where id = any(${ids})`;
    await sql.end();
  }
});
