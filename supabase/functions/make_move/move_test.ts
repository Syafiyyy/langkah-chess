import { assertEquals } from "@std/assert";
import { type ApplyMoveArgs, type GameRow, makeMove, type MoveDb, MoveDbError } from "./move.ts";

const WHITE = "00000000-0000-4000-8000-000000000001";
const BLACK = "00000000-0000-4000-8000-000000000002";
const STRANGER = "00000000-0000-4000-8000-000000000003";
const GAME = "00000000-0000-4000-8000-0000000000aa";
const MOVE_ID = "00000000-0000-4000-8000-0000000000bb";
const START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

function game(over: Partial<GameRow> = {}): GameRow {
  return {
    id: GAME,
    white_id: WHITE,
    black_id: BLACK,
    status: "active",
    fen: START,
    ply: 0,
    ...over,
  };
}

/** In-memory MoveDb; apply_move just bumps the ply like the SQL does. */
class FakeDb implements MoveDb {
  applied: ApplyMoveArgs[] = [];
  existing: { game_id: string; ply: number } | null = null;
  applyError: string | null = null;
  constructor(public row: GameRow | null, public history: string[] = []) {}

  findMove() {
    return Promise.resolve(this.existing);
  }
  loadGame() {
    return Promise.resolve(this.row);
  }
  loadHistory() {
    return Promise.resolve(this.history);
  }
  applyMove(args: ApplyMoveArgs) {
    if (this.applyError) return Promise.reject(new MoveDbError(this.applyError));
    this.applied.push(args);
    return Promise.resolve({ ...this.row!, ply: args.p_ply, fen: args.p_fen_after });
  }
}

const body = (over: Record<string, unknown> = {}) => ({
  game_id: GAME,
  ply: 1,
  uci: "e2e4",
  client_move_id: MOVE_ID,
  ...over,
});

Deno.test("legal move is applied with SAN, FEN and can-mate flags", async () => {
  const db = new FakeDb(game());
  const res = await makeMove(db, WHITE, body());
  assertEquals(res.status, 200);
  assertEquals(res.body.applied, true);
  assertEquals(db.applied, [{
    p_game: GAME,
    p_ply: 1,
    p_uci: "e2e4",
    p_san: "e4",
    p_fen_after: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
    p_result: null,
    p_termination: null,
    p_client_move_id: MOVE_ID,
    p_user: WHITE,
    p_white_can_mate: true,
    p_black_can_mate: true,
  }]);
});

Deno.test("checkmate passes the result to apply_move", async () => {
  const db = new FakeDb(
    game({
      ply: 3,
      fen: "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2",
    }),
    ["f2f3", "e7e5", "g2g4"],
  );
  const res = await makeMove(db, BLACK, body({ ply: 4, uci: "d8h4" }));
  assertEquals(res.status, 200);
  assertEquals([db.applied[0].p_result, db.applied[0].p_termination], ["black", "checkmate"]);
});

Deno.test("bad request body is rejected before any lookup", async () => {
  const db = new FakeDb(game());
  for (
    const bad of [
      {},
      body({ uci: "e2e9" }),
      body({ ply: 0 }),
      body({ ply: "1" }),
      body({ game_id: "nope" }),
      body({ client_move_id: 7 }),
    ]
  ) {
    const res = await makeMove(db, WHITE, bad);
    assertEquals([res.status, res.body.error], [400, "BAD_REQUEST"]);
  }
  assertEquals(db.applied.length, 0);
});

Deno.test("error codes before chess validation", async () => {
  const cases: [GameRow | null, string, Record<string, unknown>, number, string][] = [
    [null, WHITE, body(), 404, "NOT_FOUND"],
    [game(), STRANGER, body(), 403, "NOT_A_PLAYER"],
    [game({ status: "finished" }), WHITE, body(), 409, "GAME_OVER"],
    [game({ status: "waiting" }), WHITE, body(), 409, "GAME_OVER"],
    [game(), WHITE, body({ ply: 2 }), 409, "STALE"],
    [game(), BLACK, body(), 409, "NOT_YOUR_TURN"],
  ];
  for (const [row, user, req, status, error] of cases) {
    const db = new FakeDb(row);
    const res = await makeMove(db, user, req);
    assertEquals([res.status, res.body.error], [status, error], error);
    assertEquals(db.applied.length, 0);
  }
});

Deno.test("illegal move is rejected", async () => {
  const db = new FakeDb(game());
  const res = await makeMove(db, WHITE, body({ uci: "e2e5" }));
  assertEquals([res.status, res.body.error], [422, "ILLEGAL"]);
  assertEquals(db.applied.length, 0);
});

Deno.test("retry of an applied move returns the game without re-checking", async () => {
  // The move is already in: the game is at ply 1, so a fresh check would be STALE.
  const db = new FakeDb(game({ ply: 1 }));
  db.existing = { game_id: GAME, ply: 1 };
  const res = await makeMove(db, WHITE, body());
  assertEquals(res.status, 200);
  assertEquals(res.body.applied, true);
  assertEquals(res.body.game?.ply, 1);
  assertEquals(db.applied.length, 0);
});

Deno.test("move id reused for another game is rejected", async () => {
  const db = new FakeDb(game());
  db.existing = { game_id: "00000000-0000-4000-8000-0000000000cc", ply: 1 };
  const res = await makeMove(db, WHITE, body());
  assertEquals([res.status, res.body.error], [409, "DUPLICATE_MOVE_ID"]);
});

Deno.test("apply_move errors are mapped (race lost under the row lock)", async () => {
  const db = new FakeDb(game());
  db.applyError = "STALE";
  const res = await makeMove(db, WHITE, body());
  assertEquals([res.status, res.body.error], [409, "STALE"]);
});

Deno.test("timeout inside apply_move: game returned, move not applied", async () => {
  const db = new FakeDb(
    game({ ply: 2, fen: "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2" }),
    ["e2e4", "e7e5"],
  );
  db.applyMove = () =>
    Promise.resolve({ ...db.row!, status: "finished", result: "black", termination: "timeout" });
  const res = await makeMove(db, WHITE, body({ ply: 3, uci: "g1f3" }));
  assertEquals(res.status, 200);
  assertEquals(res.body.applied, false);
  assertEquals(res.body.game?.termination, "timeout");
});

Deno.test("the user check and all lookups run at the same time", async () => {
  const started: string[] = [];
  let release!: () => void;
  const gate = new Promise<void>((r) => (release = r));
  const db = new FakeDb(game());
  const wrap = <T>(name: string, value: () => Promise<T>) => async () => {
    started.push(name);
    await gate;
    return value();
  };
  db.loadGame = wrap("game", () => Promise.resolve(db.row));
  db.findMove = wrap("move", () => Promise.resolve(null));
  db.loadHistory = wrap("history", () => Promise.resolve([]));
  const user = wrap("user", () => Promise.resolve<string | null>(WHITE))();

  const res = makeMove(db, user, body());
  await Promise.resolve();
  // Nothing has finished yet, but every request is already on its way.
  assertEquals(started.sort(), ["game", "history", "move", "user"]);
  release();
  assertEquals((await res).status, 200);
});

Deno.test("no user: 401, nothing applied, even with a bad body", async () => {
  const db = new FakeDb(game());
  assertEquals((await makeMove(db, Promise.resolve(null), body())).status, 401);
  assertEquals((await makeMove(db, null, { nonsense: true })).status, 401);
  assertEquals(db.applied, []);
});
