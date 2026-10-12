import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File;
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/play_ai/domain/uci_move.dart';

/// The shared fixture `test/fixtures/tricky_positions.json` is dartchess's
/// answer for each position: every legal move (standard UCI) with its SAN,
/// FEN after and how the game stands. The make_move Edge Function tests
/// (`supabase/functions/_shared/chess_rules_test.ts`) check chess.js against
/// the same file. Regenerate with `UPDATE_FIXTURES=1 flutter test <this file>`.
const _fixturePath = 'test/fixtures/tricky_positions.json';

const _positions = <String, String>{
  'start': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'castling both sides': 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
  'castling black': 'r3k2r/8/8/8/8/8/8/R3K2R b kq - 0 1',
  'castling through check': '4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1',
  'castling out of check': '4k3/8/8/8/8/8/4r3/R3K2R w KQ - 0 1',
  'castling rights lost': 'r3k2r/8/8/8/8/8/8/R3K2R w - - 0 1',
  'en passant': '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2',
  'en passant pinned': '8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 2',
  'ep square without capturer': '4k3/8/8/8/3P4/8/8/4K3 b - d3 0 1',
  'promotion': '8/P6k/8/8/8/8/8/4K3 w - - 0 1',
  'capture promotion': '1r5k/P7/8/8/8/8/8/4K3 w - - 0 1',
  'black promotion with check': '4k3/8/8/8/8/8/p7/4K2R b - - 0 1',
  'promotion mate': 'k7/7P/1K6/8/8/8/8/8 w - - 0 1',
  'in check': '4k3/4r3/8/8/8/8/8/R3K3 w Q - 0 1',
  'double check': '4k3/8/8/8/8/5n2/8/4K2r w - - 0 1',
  'fools mate': 'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
  'back rank mate': '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
  'stalemate trap': '7k/5Q2/6K1/8/8/8/8/8 w - - 0 1',
  'capture to bare kings': '8/8/8/4k3/8/8/4r3/4K3 w - - 0 1',
  'knight vs king': '8/8/8/4k3/8/8/2n5/4K2R w - - 0 1',
};

Map<String, Object?> _describe(String name, String fen) {
  final position = Chess.fromSetup(Setup.parseFen(fen));
  final moves = <String, Object?>{};
  for (final MapEntry(key: from, value: targets) in position.legalMoves.entries) {
    for (final to in targets.squares) {
      final isPromotion = position.board.pieceAt(from)?.role == Role.pawn &&
          SquareSet.backranks.has(to);
      final promotions = isPromotion
          ? [Role.queen, Role.rook, Role.bishop, Role.knight]
          : <Role?>[null];
      for (final role in promotions) {
        final move = NormalMove(from: from, to: to, promotion: role);
        final (after, san) = position.makeSan(move);
        moves[standardUci(position, move)] = {
          'san': san,
          'fenAfter': after.fen,
          'check': after.isCheck,
          'checkmate': after.isCheckmate,
          'stalemate': after.isStalemate,
          'whiteInsufficient': after.hasInsufficientMaterial(Side.white),
          'blackInsufficient': after.hasInsufficientMaterial(Side.black),
        };
      }
    }
  }
  final sorted = moves.keys.toList()..sort();
  return {
    'name': name,
    'fen': fen,
    'normalizedFen': position.fen,
    'legal': sorted,
    'moves': {for (final uci in sorted) uci: moves[uci]},
  };
}

void main() {
  test('tricky positions fixture matches dartchess', () {
    final expected = [
      for (final MapEntry(key: name, value: fen) in _positions.entries)
        _describe(name, fen),
    ];
    final json = '${const JsonEncoder.withIndent('  ').convert(expected)}\n';
    final file = File(_fixturePath);
    if (Platform.environment['UPDATE_FIXTURES'] == '1') {
      file.writeAsStringSync(json);
    }
    // Git may check the file out with CRLF on Windows.
    expect(file.readAsStringSync().replaceAll('\r\n', '\n'), json);
  });
}
