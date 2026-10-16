// make_move round-trip latency against the REAL project (ADR-0004 asks for
// it in the README). Two existing test users play a 20-ply Ruy Lopez through
// create_invite / join_invite and make_move; every make_move call is timed on
// this machine (the first call after a deploy or a long idle is the cold
// one). The game is resigned at the end. Only the publishable key and the
// users' own passwords are used. Run:
//   SKAK_URL=https://<ref>.supabase.co SKAK_PUBLISHABLE_KEY=sb_publishable_... \
//   SKAK_A_EMAIL=... SKAK_A_PASSWORD=... SKAK_B_EMAIL=... SKAK_B_PASSWORD=... \
//   npx deno run --config supabase/functions/deno.json --allow-net --allow-env \
//     supabase/scripts/latency.ts
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = need("SKAK_URL");
const publishable = need("SKAK_PUBLISHABLE_KEY");

function need(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`set ${name}`);
  return value;
}

interface Player {
  id: string;
  client: SupabaseClient;
}

async function signIn(who: "A" | "B"): Promise<Player> {
  const client = createClient(url, publishable, { auth: { persistSession: false } });
  const { data, error } = await client.auth.signInWithPassword({
    email: need(`SKAK_${who}_EMAIL`),
    password: need(`SKAK_${who}_PASSWORD`),
  });
  if (error) throw error;
  return { id: data.user.id, client };
}

const MOVES = [
  "e2e4",
  "e7e5",
  "g1f3",
  "b8c6",
  "f1b5",
  "a7a6",
  "b5a4",
  "g8f6",
  "e1g1",
  "f8e7",
  "f1e1",
  "b7b5",
  "a4b3",
  "d7d6",
  "c2c3",
  "e8g8",
  "h2h3",
  "c6a5",
  "b3c2",
  "c7c5",
];

const a = await signIn("A");
const b = await signIn("B");
const invite = await a.client.rpc("create_invite", { p_time_base_ms: 600000, p_increment_ms: 0 });
if (invite.error) throw invite.error;
const joined = await b.client.rpc("join_invite", { p_code: invite.data.invite_code });
if (joined.error) throw joined.error;
const game = joined.data;
const white = game.white_id === a.id ? a : b;
const black = white === a ? b : a;

const times: number[] = [];
for (let i = 0; i < MOVES.length; i++) {
  const mover = i % 2 === 0 ? white : black;
  const start = performance.now();
  const res = await mover.client.functions.invoke("make_move", {
    body: { game_id: game.id, ply: i + 1, uci: MOVES[i], client_move_id: crypto.randomUUID() },
  });
  const ms = Math.round(performance.now() - start);
  if (res.error || !res.data.applied) {
    throw new Error(`ply ${i + 1}: ${res.error ?? "not applied"}`);
  }
  times.push(ms);
  console.log(`ply ${String(i + 1).padStart(2)}: ${ms} ms`);
}
await white.client.rpc("resign", { p_game: game.id });

const warm = times.slice(1).sort((x, y) => x - y);
const median = (xs: number[]) => xs[Math.floor(xs.length / 2)];
console.log(`first call: ${times[0]} ms`);
console.log(`later calls: median ${median(warm)} ms, min ${warm[0]} ms, max ${warm.at(-1)} ms`);
console.log(`game ${game.id} (resigned)`);
