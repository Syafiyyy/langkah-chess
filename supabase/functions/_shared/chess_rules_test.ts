import { assertEquals, assertThrows } from "@std/assert";
import { Chess } from "chess.js";
import {
  checkMove,
  hasInsufficientMaterial,
  legalUcis,
  normalizedFen,
  playUci,
  resultAfterMove,
} from "./chess_rules.ts";

// Generated from dartchess by test/online/tricky_positions_test.dart.
interface FixtureMove {
  san: string;
  fenAfter: string;
  check: boolean;
  checkmate: boolean;
  stalemate: boolean;
  whiteInsufficient: boolean;
  blackInsufficient: boolean;
}
interface FixturePosition {
  name: string;
  fen: string;
  normalizedFen: string;
  legal: string[];
  moves: Record<string, FixtureMove>;
}
const fixture: FixturePosition[] = JSON.parse(
  await Deno.readTextFile(
    new URL("../../../test/fixtures/tricky_positions.json", import.meta.url),
  ),
);

for (const position of fixture) {
  Deno.test(`fixture: ${position.name}`, () => {
    assertEquals(normalizedFen(new Chess(position.fen)), position.normalizedFen);
    assertEquals(legalUcis(position.fen), position.legal);
    for (const uci of position.legal) {
      const chess = new Chess(position.fen);
      const move = playUci(chess, uci);
      const expected = position.moves[uci];
      assertEquals(
        {
          san: move?.san,
          fenAfter: normalizedFen(chess),
          check: chess.inCheck(),
          checkmate: chess.isCheckmate(),
          stalemate: chess.isStalemate(),
          whiteInsufficient: hasInsufficientMaterial(chess, "w"),
          blackInsufficient: hasInsufficientMaterial(chess, "b"),
        },
        expected,
        uci,
      );
    }
  });
}

const START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

Deno.test("checkMove: legal move gives SAN, FEN and no end", () => {
  const checked = checkMove([], START, "e2e4");
  assertEquals(checked?.san, "e4");
  assertEquals(
    checked?.fenAfter,
    "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
  );
  assertEquals(checked?.end, null);
  assertEquals([checked?.whiteCanMate, checked?.blackCanMate], [true, true]);
});

Deno.test("checkMove: illegal move and wrong side return null", () => {
  assertEquals(checkMove([], START, "e2e5"), null);
  assertEquals(checkMove([], START, "e7e5"), null);
  assertEquals(checkMove([], START, "e1g1"), null);
});

Deno.test("checkMove: fool's mate ends in checkmate for black", () => {
  const history = ["f2f3", "e7e5", "g2g4"];
  const fen = "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq - 0 2";
  assertEquals(checkMove(history, fen, "d8h4")?.end, {
    result: "black",
    termination: "checkmate",
  });
});

function fenAfter(history: string[]): string {
  const chess = new Chess();
  history.forEach((uci) => playUci(chess, uci));
  return normalizedFen(chess);
}

Deno.test("checkMove: third occurrence is threefold repetition", () => {
  const shuffle = ["g1f3", "g8f6", "f3g1", "f6g8"];
  // After one shuffle the start position has occurred twice: no draw.
  const once = shuffle.slice(0, 3);
  assertEquals(checkMove(once, fenAfter(once), "f6g8")?.end, null);
  // After the second shuffle it is the third time.
  const twice = [...shuffle, ...shuffle.slice(0, 3)];
  assertEquals(checkMove(twice, fenAfter(twice), "f6g8")?.end, {
    result: "draw",
    termination: "threefoldRepetition",
  });
});

Deno.test("checkMove: history must match the stored FEN", () => {
  assertThrows(() => checkMove(["e2e4"], START, "e7e5"));
  assertThrows(() => checkMove(["e2e5"], START, "e7e5"));
});

Deno.test("resultAfterMove: 75-move rule after 150 quiet half-moves", () => {
  // Rook shuffles can't make 150 quiet plies without repeating, so use the
  // result function on a FEN with the counter at 149.
  const chess = new Chess("4k3/8/8/8/8/8/8/R3K3 w - - 149 100");
  playUci(chess, "a1a2");
  assertEquals(Number(chess.fen().split(" ")[4]), 150);
  assertEquals(resultAfterMove(chess, 1), {
    result: "draw",
    termination: "seventyFiveMoveRule",
  });
});

Deno.test("resultAfterMove: mate beats the 75-move rule", () => {
  const chess = new Chess("6k1/5ppp/8/8/8/8/8/R5K1 w - - 149 100");
  playUci(chess, "a1a8");
  assertEquals(resultAfterMove(chess, 1)?.termination, "checkmate");
});

Deno.test("hasInsufficientMaterial: knight only when the opponent has no blockers", () => {
  // As dartchess: K+N can't mate a bare king, but can mate a king whose own
  // rook takes away its escape square.
  const bare = new Chess("8/8/8/4k3/8/8/2n5/4K3 b - - 0 1");
  assertEquals(hasInsufficientMaterial(bare, "b"), true);
  const withRook = new Chess("8/8/8/4k3/8/8/2n5/4K2R b - - 0 1");
  assertEquals(hasInsufficientMaterial(withRook, "b"), false);
  assertEquals(hasInsufficientMaterial(withRook, "w"), false);
});
