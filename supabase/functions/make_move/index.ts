// Edge Function make_move (ADR-0004): POST { game_id, ply, uci, client_move_id }
// with the user's JWT. Validates the move with chess.js and applies it through
// apply_move (service role). Returns { game, applied } or { error }.
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

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });
  const userId = await userIdFrom(req);
  if (!userId) return json(401, { error: "UNAUTHORIZED" });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "BAD_REQUEST" });
  }
  try {
    const res = await makeMove(db, userId, body);
    return json(res.status, res.body);
  } catch (e) {
    console.error("make_move failed", e);
    return json(500, { error: "INTERNAL" });
  }
});
