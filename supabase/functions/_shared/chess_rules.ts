// Chess rules for the server, on chess.js. Mirrors the app's offline rules
// (lib/features/play_ai/domain/game_result.dart) so online and offline games
// end the same way. Termination names match the Dart `Termination` enum.
import { Chess, type Move } from "npm:chess.js@1.4.0";

export type Side = "w" | "b";
export type Result = "white" | "black" | "draw";
export interface GameEnd {
  result: Result;
  termination: string;
}

/** Plays `ucis` from the standard start. Throws on an illegal move. */
export function replay(ucis: string[]): Chess {
  const chess = new Chess();
  for (const uci of ucis) {
    if (!playUci(chess, uci)) throw new Error(`illegal move in history: ${uci}`);
  }
  return chess;
}

/**
 * Plays one UCI move (`e2e4`, `e7e8q`, castling as the king move `e1g1`) if
 * it is legal for the side to move. Returns the move, or null if illegal.
 */
export function playUci(chess: Chess, uci: string): Move | null {
  const move = chess.moves({ verbose: true }).find((m) => m.lan === uci);
  if (!move) return null;
  return chess.move({ from: move.from, to: move.to, promotion: move.promotion });
}

/** All legal moves in UCI, sorted. */
export function legalUcis(fen: string): string[] {
  return new Chess(fen).moves({ verbose: true }).map((m) => m.lan).sort();
}

function hasLegalEnPassant(chess: Chess): boolean {
  return chess.moves({ verbose: true }).some((m) => m.flags.includes("e"));
}

/** FEN with the en-passant square only when a capture is legal (as dartchess). */
export function normalizedFen(chess: Chess): string {
  const fields = chess.fen().split(" ");
  if (!hasLegalEnPassant(chess)) fields[3] = "-";
  return fields.join(" ");
}

/** Placement + side + castling + legal ep square; counters ignored. */
export function positionKey(chess: Chess): string {
  return normalizedFen(chess).split(" ").slice(0, 4).join(" ");
}

function isDarkSquare(square: string): boolean {
  const file = square.charCodeAt(0) - 97;
  const rank = Number(square[1]) - 1;
  return (file + rank) % 2 === 0;
}

/** Port of dartchess `Position.hasInsufficientMaterial(side)` (standard chess). */
export function hasInsufficientMaterial(chess: Chess, side: Side): boolean {
  const pieces = chess.board().flat().filter((p) => p !== null);
  const own = pieces.filter((p) => p.color === side);
  const theirs = pieces.filter((p) => p.color !== side);
  if (own.some((p) => p.type === "p" || p.type === "r" || p.type === "q")) {
    return false;
  }
  if (own.some((p) => p.type === "n")) {
    return own.length <= 2 &&
      theirs.every((p) => p.type === "k" || p.type === "q");
  }
  if (own.some((p) => p.type === "b")) {
    const bishops = pieces.filter((p) => p.type === "b");
    const sameColor = !bishops.some((p) => isDarkSquare(p.square)) ||
      !bishops.some((p) => !isDarkSquare(p.square));
    return sameColor && !pieces.some((p) => p.type === "p" || p.type === "n");
  }
  return true;
}

/**
 * Result once `chess` is reached, or null if the game goes on. `repetitions`
 * counts this position's key including now. Checkmate beats every draw;
 * threefold and the 75-move rule are automatic (as offline).
 */
export function resultAfterMove(chess: Chess, repetitions: number): GameEnd | null {
  if (chess.isCheckmate()) {
    return { result: chess.turn() === "w" ? "black" : "white", termination: "checkmate" };
  }
  if (chess.isStalemate()) return { result: "draw", termination: "stalemate" };
  if (hasInsufficientMaterial(chess, "w") && hasInsufficientMaterial(chess, "b")) {
    return { result: "draw", termination: "insufficientMaterial" };
  }
  const halfmoves = Number(chess.fen().split(" ")[4]);
  if (halfmoves >= 150) return { result: "draw", termination: "seventyFiveMoveRule" };
  if (repetitions >= 3) return { result: "draw", termination: "threefoldRepetition" };
  return null;
}

export interface CheckedMove {
  san: string;
  fenAfter: string;
  end: GameEnd | null;
  whiteCanMate: boolean;
  blackCanMate: boolean;
}

/**
 * Validates `uci` after the game's `history` and computes everything
 * apply_move needs. Returns null if the move is illegal. Throws if the
 * history does not lead to `storedFen` (data corruption).
 */
export function checkMove(history: string[], storedFen: string, uci: string): CheckedMove | null {
  const chess = new Chess();
  const seen = new Map<string, number>([[positionKey(chess), 1]]);
  for (const past of history) {
    if (!playUci(chess, past)) throw new Error(`illegal move in history: ${past}`);
    const key = positionKey(chess);
    seen.set(key, (seen.get(key) ?? 0) + 1);
  }
  if (normalizedFen(chess) !== normalizeFenString(storedFen)) {
    throw new Error("history does not match the stored position");
  }
  const move = playUci(chess, uci);
  if (!move) return null;
  const key = positionKey(chess);
  return {
    san: move.san,
    fenAfter: normalizedFen(chess),
    end: resultAfterMove(chess, (seen.get(key) ?? 0) + 1),
    whiteCanMate: !hasInsufficientMaterial(chess, "w"),
    blackCanMate: !hasInsufficientMaterial(chess, "b"),
  };
}

function normalizeFenString(fen: string): string {
  return normalizedFen(new Chess(fen));
}
