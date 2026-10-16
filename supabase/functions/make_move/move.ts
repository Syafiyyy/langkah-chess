// make_move logic, separate from HTTP and Supabase so it can be unit-tested.
// The checks here give clear errors early; apply_move repeats the game checks
// under the row lock and is the authority (ADR-0004).
import { checkMove } from "../_shared/chess_rules.ts";

export interface GameRow {
  id: string;
  white_id: string | null;
  black_id: string | null;
  status: string;
  fen: string;
  ply: number;
  [column: string]: unknown;
}

export interface ApplyMoveArgs {
  p_game: string;
  p_ply: number;
  p_uci: string;
  p_san: string;
  p_fen_after: string;
  p_result: string | null;
  p_termination: string | null;
  p_client_move_id: string;
  p_user: string;
  p_white_can_mate: boolean;
  p_black_can_mate: boolean;
}

/** An error code raised by apply_move (`STALE`, `GAME_OVER`, ...). */
export class MoveDbError extends Error {}

export interface MoveDb {
  findMove(clientMoveId: string): Promise<{ game_id: string; ply: number } | null>;
  loadGame(gameId: string): Promise<GameRow | null>;
  /** UCI moves of the game in ply order. */
  loadHistory(gameId: string): Promise<string[]>;
  applyMove(args: ApplyMoveArgs): Promise<GameRow>;
}

export interface MoveResponse {
  status: number;
  body: { game?: GameRow; applied?: boolean; error?: string };
}

const STATUS: Record<string, number> = {
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  NOT_A_PLAYER: 403,
  NOT_FOUND: 404,
  STALE: 409,
  NOT_YOUR_TURN: 409,
  GAME_OVER: 409,
  DUPLICATE_MOVE_ID: 409,
  ILLEGAL: 422,
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const UCI = /^[a-h][1-8][a-h][1-8][qrbn]?$/;

function fail(error: string): MoveResponse {
  return { status: STATUS[error] ?? 500, body: { error } };
}

/**
 * [user] is the caller's id (or a pending lookup of it, null when the token is
 * invalid). The user lookup and the game, move-id and history reads run at the
 * same time; nothing is returned before the user check passes.
 */
export async function makeMove(
  db: MoveDb,
  user: string | null | Promise<string | null>,
  req: unknown,
): Promise<MoveResponse> {
  const { game_id, ply, uci, client_move_id } = (req ?? {}) as Record<string, unknown>;
  if (
    typeof game_id !== "string" || !UUID.test(game_id) ||
    typeof client_move_id !== "string" || !UUID.test(client_move_id) ||
    !Number.isInteger(ply) || (ply as number) < 1 ||
    typeof uci !== "string" || !UCI.test(uci)
  ) {
    return fail(await user ? "BAD_REQUEST" : "UNAUTHORIZED");
  }
  const plyNo = ply as number;

  const [userId, game, existing, history] = await Promise.all([
    user,
    db.loadGame(game_id),
    db.findMove(client_move_id),
    db.loadHistory(game_id),
  ]);
  if (!userId) return fail("UNAUTHORIZED");
  if (!game) return fail("NOT_FOUND");
  if (userId !== game.white_id && userId !== game.black_id) return fail("NOT_A_PLAYER");

  // Retry of an attempt that already went through: report the game as it is.
  if (existing) {
    if (existing.game_id !== game_id) return fail("DUPLICATE_MOVE_ID");
    return { status: 200, body: { game, applied: true } };
  }

  if (game.status !== "active") return fail("GAME_OVER");
  if (plyNo !== game.ply + 1) return fail("STALE");
  const mover = game.ply % 2 === 0 ? game.white_id : game.black_id;
  if (userId !== mover) return fail("NOT_YOUR_TURN");

  const checked = checkMove(history, game.fen, uci);
  if (!checked) return fail("ILLEGAL");

  try {
    const after = await db.applyMove({
      p_game: game_id,
      p_ply: plyNo,
      p_uci: uci,
      p_san: checked.san,
      p_fen_after: checked.fenAfter,
      p_result: checked.end?.result ?? null,
      p_termination: checked.end?.termination ?? null,
      p_client_move_id: client_move_id,
      p_user: userId,
      p_white_can_mate: checked.whiteCanMate,
      p_black_can_mate: checked.blackCanMate,
    });
    // Not applied when the mover's clock had already run out.
    return { status: 200, body: { game: after, applied: after.ply === plyNo } };
  } catch (e) {
    if (e instanceof MoveDbError && e.message in STATUS) return fail(e.message);
    throw e;
  }
}
