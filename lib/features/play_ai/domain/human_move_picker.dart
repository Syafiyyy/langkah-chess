import 'dart:math';

import 'package:dartchess/dartchess.dart';

import '../../../core/chess/win_percent.dart';
import 'human_style.dart';

/// One engine candidate: a move and its score for the side to move.
class MoveCandidate {
  const MoveCandidate({required this.uci, this.cp, this.mate});

  final String uci;
  final int? cp;
  final int? mate;
}

/// The chosen move, and whether it loses 30+ win% versus the best candidate
/// (an unscored random move counts as one).
class BotPick {
  const BotPick(this.uci, {required this.bigBlunder});

  final String uci;
  final bool bigBlunder;
}

/// Picks a human-looking move from engine candidates (levels 1–4).
///
/// In order:
/// 1. A mate in one is played unless missed ([HumanStyle.missMateInOneChance]).
/// 2. Newcomer only: sometimes any legal move ([HumanStyle.randomMoveChance]).
/// 3. Sometimes a clearly worse candidate on purpose (drop >= 10 win%).
/// 4. Otherwise softmax over candidates by win% drop and temperature.
///
/// Guardrails: only legal moves; never two big blunders (drop >= 30) in a
/// row. One picker per game: it remembers the previous pick.
class HumanMovePicker {
  HumanMovePicker(this.style, this._random);

  final HumanStyle style;
  final Random _random;
  bool _lastWasBig = false;

  static const _bigDrop = 30.0;
  static const _blunderDrop = 10.0;

  BotPick pick(Position position, List<MoveCandidate> candidates) {
    final scored = <({String uci, double drop, bool mateInOne})>[];
    final wins = <String, double>{};
    for (final c in candidates) {
      final move = Move.parse(c.uci);
      if (move == null || !position.isLegal(move) || wins.containsKey(c.uci)) {
        continue;
      }
      if (c.cp == null && c.mate == null) continue;
      wins[c.uci] = winPercent(cp: c.cp, mate: c.mate);
    }
    if (wins.isEmpty) return _record(_randomLegal(position), big: false);
    final best = wins.values.reduce(max);
    for (final c in candidates.where((c) => wins.containsKey(c.uci))) {
      if (scored.any((s) => s.uci == c.uci)) continue;
      scored.add((
        uci: c.uci,
        drop: best - wins[c.uci]!,
        mateInOne: c.mate == 1,
      ));
    }

    // 1. Mate in one.
    final mates = scored.where((s) => s.mateInOne).toList();
    if (mates.isNotEmpty) {
      if (_random.nextDouble() >= style.missMateInOneChance) {
        return _record(mates.first.uci, big: false);
      }
      scored.removeWhere((s) => s.mateInOne);
      if (scored.isEmpty) return _record(mates.first.uci, big: false);
    }

    // 2. Any legal move.
    if (!_lastWasBig && _random.nextDouble() < style.randomMoveChance) {
      final uci = _randomLegal(position);
      final known = scored.where((s) => s.uci == uci).firstOrNull;
      return _record(uci, big: known == null || known.drop >= _bigDrop);
    }

    final allowBig = !_lastWasBig;
    var pool = scored.where((s) => allowBig || s.drop < _bigDrop).toList();
    if (pool.isEmpty) {
      pool = [scored.reduce((a, b) => a.drop <= b.drop ? a : b)];
    }

    // 3. Deliberate mistake.
    if (_random.nextDouble() < style.blunderChance) {
      final worse = pool
          .where(
            (s) =>
                s.drop >= _blunderDrop &&
                (style.bigBlunders || s.drop < _bigDrop),
          )
          .toList();
      if (worse.isNotEmpty) {
        final s = worse[_random.nextInt(worse.length)];
        return _record(s.uci, big: s.drop >= _bigDrop);
      }
    }

    // 4. Softmax by win% drop.
    final weights = [for (final s in pool) exp(-s.drop / style.temperature)];
    var r = _random.nextDouble() * weights.reduce((a, b) => a + b);
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r <= 0) return _record(pool[i].uci, big: pool[i].drop >= _bigDrop);
    }
    return _record(pool.last.uci, big: pool.last.drop >= _bigDrop);
  }

  BotPick _record(String uci, {required bool big}) {
    _lastWasBig = big;
    return BotPick(uci, bigBlunder: big);
  }

  String _randomLegal(Position position) {
    final moves = [
      for (final e in position.legalMoves.entries)
        for (final to in e.value.squares) NormalMove(from: e.key, to: to),
    ];
    var move = moves[_random.nextInt(moves.length)];
    final piece = position.board.roleAt(move.from);
    if (piece == Role.pawn &&
        (move.to.rank == Rank.first || move.to.rank == Rank.eighth)) {
      move = move.withPromotion(Role.queen);
    }
    return move.uci;
  }
}
