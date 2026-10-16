// Smoke test against the REAL project: two test users (smoke_white,
// smoke_black) play Fool's mate through create_invite / join_invite and the
// make_move Edge Function, with a retry, a stale move, an illegal move and a
// wrong-turn move on the way. Prints the final state; exits 1 on any surprise.
//
// The secret key is only used to make sure the two users exist and to give
// them a fresh random password for this run; nothing is stored. Run:
//   SKAK_URL=https://<ref>.supabase.co SKAK_PUBLISHABLE_KEY=sb_publishable_... \
//   SKAK_SECRET_KEY=sb_secret_... \
//   npx deno run --config supabase/functions/deno.json --allow-net --allow-env \
//     supabase/scripts/smoke.ts
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = need("SKAK_URL");
const publishable = need("SKAK_PUBLISHABLE_KEY");
const admin = createClient(url, need("SKAK_SECRET_KEY"), {
  auth: { persistSession: false, autoRefreshToken: false },
});

function need(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`set ${name}`);
  return value;
}

function check(ok: boolean, what: string): void {
  console.log(`${ok ? "ok  " : "FAIL"} ${what}`);
  if (!ok) Deno.exit(1);
}

interface Player {
  name: string;
  id: string;
  client: SupabaseClient;
  token: string;
}

/** Creates the user if needed, sets a random password, signs in. */
async function player(name: string): Promise<Player> {
  const email = `${name}@example.com`;
  const password = crypto.randomUUID() + crypto.randomUUID();
  const created = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (created.error) {
    const { data, error } = await admin.auth.admin.listUsers({ perPage: 1000 });
    if (error) throw error;
    const user = data.users.find((u) => u.email === email);
    if (!user) throw created.error;
    const updated = await admin.auth.admin.updateUserById(user.id, { password });
    if (updated.error) throw updated.error;
  }
  const client = createClient(url, publishable, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
  const profile = await client.rpc("set_profile", { p_username: name, p_avatar: null });
  if (profile.error) throw profile.error;
  return { name, id: data.user.id, client, token: data.session.access_token };
}

async function rpc<T>(p: Player, fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await p.client.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message}`);
  return data as T;
}

async function makeMove(p: Player, body: Record<string, unknown>) {
  const res = await fetch(`${url}/functions/v1/make_move`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${p.token}`,
      apikey: publishable,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

interface Game {
  id: string;
  invite_code: string;
  white_id: string;
  black_id: string;
  status: string;
  ply: number;
  result: string | null;
  termination: string | null;
  white_ms: number;
  black_ms: number;
}

const white = await player("smoke_white");
const black = await player("smoke_black");
console.log(`users: smoke_white ${white.id}, smoke_black ${black.id}`);
const ratings = async () =>
  (await admin.from("profiles").select("username, rating, games_played")
    .in("id", [white.id, black.id]).order("username")).data;
const before = await ratings();

// Colours are random on join: abort and retry until smoke_white is White.
let game: Game | null = null;
for (let attempt = 1; attempt <= 10 && !game; attempt++) {
  const invite = await rpc<Game>(white, "create_invite", {
    p_time_base_ms: 300000,
    p_increment_ms: 2000,
  });
  const joined = await rpc<Game>(black, "join_invite", { p_code: invite.invite_code });
  if (joined.white_id === white.id) {
    game = joined;
  } else {
    await rpc<Game>(white, "abort", { p_game: joined.id });
  }
}
check(game !== null, "invite joined with smoke_white as White");
const id = game!.id;
console.log(`game ${id} (invite ${game!.invite_code})`);

const move = (p: Player, ply: number, uci: string, moveId = crypto.randomUUID()) =>
  makeMove(p, { game_id: id, ply, uci, client_move_id: moveId });

const first = crypto.randomUUID();
let r = await move(white, 1, "f2f3", first);
check(r.status === 200 && r.body.applied && r.body.game.ply === 1, "1. f3 applied");
r = await move(white, 1, "f2f3", first);
check(
  r.status === 200 && r.body.applied && r.body.game.ply === 1,
  "retry: same result, no 2nd move",
);
r = await move(white, 2, "e2e4");
check(r.status === 409 && r.body.error === "NOT_YOUR_TURN", "White cannot move twice");
r = await move(black, 2, "e7e1");
check(r.status === 422 && r.body.error === "ILLEGAL", "illegal move rejected");
r = await move(black, 2, "e7e5");
check(r.status === 200 && r.body.applied, "1... e5 applied");
r = await move(black, 2, "d7d5");
check(r.status === 409 && r.body.error === "STALE", "stale ply rejected");
r = await move(white, 3, "g2g4");
check(r.status === 200 && r.body.applied, "2. g4 applied");
r = await move(black, 4, "d8h4");
check(r.status === 200 && r.body.applied, "2... Qh4# applied");

const final = r.body.game as Game;
check(
  final.status === "finished" && final.result === "black" && final.termination === "checkmate",
  "game over: Black wins by checkmate",
);
const moves = (await white.client.from("moves").select("ply, san, white_ms, black_ms")
  .eq("game_id", id).order("ply")).data;
check(moves?.length === 4, "4 moves stored, readable by a player");
const stranger = createClient(url, publishable, { auth: { persistSession: false } });
const hidden = await stranger.from("games").select("id").eq("id", id);
check((hidden.data ?? []).length === 0, "the game is not readable without signing in");

console.log(
  "\nfinal state:",
  JSON.stringify(
    {
      id,
      status: final.status,
      result: final.result,
      termination: final.termination,
      clocks_ms: { white: final.white_ms, black: final.black_ms },
      moves: moves?.map((m) => m.san).join(" "),
      ratings: { before, after: await ratings() },
    },
    null,
    2,
  ),
);
