// Edge Function make_move (ADR-0004): POST { game_id, ply, uci, client_move_id }
// with the user's JWT. Validates the move with chess.js and applies it through
// apply_move (service role). Returns { game, applied } or { error }, both with
// server_now.
import { admin, json, userIdFrom } from "../_shared/admin.ts";
import { type GameRow, makeMove, type MoveDb, MoveDbError } from "./move.ts";

const db: MoveDb = {
  async findMove(clientMoveId) {
    const { data, error } = await admin.from("moves").select("game_id, ply")
      .eq("client_move_id", clientMoveId).maybeSingle();
    if (error) throw error;
    return data;
  },
  async loadGame(gameId) {
    const { data, error } = await admin.from("games").select("*").eq("id", gameId)
      .maybeSingle();
    if (error) throw error;
    return data as GameRow | null;
  },
  async loadHistory(gameId) {
    const { data, error } = await admin.from("moves").select("uci")
      .eq("game_id", gameId).order("ply");
    if (error) throw error;
    return data.map((m) => m.uci as string);
  },
  async applyMove(args) {
    const { data, error } = await admin.rpc("apply_move", args);
    if (error) {
      if (error.code === "P0001") throw new MoveDbError(error.message);
      throw error;
    }
    return data as GameRow;
  },
};

// Every response carries server_now for the client's clock offset (ADR-0005).
function reply(status: number, body: Record<string, unknown>): Response {
  return json(status, { ...body, server_now: new Date().toISOString() });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
  if (!req.headers.get("Authorization")) return reply(401, { error: "UNAUTHORIZED" });
  // Started now, awaited inside makeMove together with the game reads.
  const user = userIdFrom(req);
  try {
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      body = null; // makeMove answers UNAUTHORIZED or BAD_REQUEST
    }
    const res = await makeMove(db, user, body);
    return reply(res.status, res.body);
  } catch (e) {
    console.error("make_move failed", e);
    return reply(500, { error: "INTERNAL" });
  }
});
