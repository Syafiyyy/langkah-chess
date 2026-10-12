import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/chess/win_percent.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/human_move_picker.dart';

/// Start position with made-up evals: a few good moves, some bad ones and
/// two that lose a lot (win% drop >= 30 from the best).
final _quiet = [
  const MoveCandidate(uci: 'e2e4', cp: 30),
  const MoveCandidate(uci: 'd2d4', cp: 28),
  const MoveCandidate(uci: 'g1f3', cp: 25),
  const MoveCandidate(uci: 'c2c4', cp: 20),
  const MoveCandidate(uci: 'b1c3', cp: 5),
  const MoveCandidate(uci: 'a2a3', cp: -10),
  const MoveCandidate(uci: 'h2h4', cp: -60),
  const MoveCandidate(uci: 'f2f3', cp: -120),
  const MoveCandidate(uci: 'g2g4', cp: -400),
  const MoveCandidate(uci: 'f2f4', cp: -500),
];

/// White to move, Ra8 is mate in one.
final _backRank = Chess.fromSetup(
  Setup.parseFen('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'),
);
final _mateInOne = [
  const MoveCandidate(uci: 'a1a8', mate: 1),
  const MoveCandidate(uci: 'a1a7', cp: 450),
  const MoveCandidate(uci: 'a1e1', cp: 430),
  const MoveCandidate(uci: 'g1f1', cp: 420),
  const MoveCandidate(uci: 'h2h3', cp: 410),
];

HumanMovePicker _picker(int level, [int seed = 1]) =>
    HumanMovePicker(BotLevel.of(level).style!, Random(seed));

/// Share of [n] picks equal to [uci].
double _rate(
  HumanMovePicker p,
  Position pos,
  List<MoveCandidate> c,
  String uci, {
  int n = 1000,
}) {
  var hits = 0;
  for (var i = 0; i < n; i++) {
    if (p.pick(pos, c).uci == uci) hits++;
  }
  return hits / n;
}

double _bigBlunderRate(HumanMovePicker p, {int n = 1000}) {
  var big = 0;
  for (var i = 0; i < n; i++) {
    if (p.pick(Chess.initial, _quiet).bigBlunder) big++;
  }
  return big / n;
}

void main() {
  test('levels 1 to 4 have a human style; 5 to 8 do not', () {
    for (final n in [1, 2, 3, 4]) {
      expect(BotLevel.of(n).style, isNotNull, reason: 'level $n');
    }
    for (final n in [5, 6, 7, 8]) {
      expect(BotLevel.of(n).style, isNull, reason: 'level $n');
    }
  });

  test('never plays an illegal candidate', () {
    final p = _picker(1);
    final withIllegal = [const MoveCandidate(uci: 'e2e5', cp: 900), ..._quiet];
    for (var i = 0; i < 2000; i++) {
      final uci = p.pick(Chess.initial, withIllegal).uci;
      expect(Chess.initial.isLegal(Move.parse(uci)!), isTrue, reason: uci);
    }
  });

  test('with no usable candidates it still plays a legal move', () {
    final uci = _picker(3).pick(Chess.initial, const []).uci;
    expect(Chess.initial.isLegal(Move.parse(uci)!), isTrue);
  });

  test('the same seed gives the same moves', () {
    List<String> run() {
      final p = _picker(2, 99);
      return [for (var i = 0; i < 50; i++) p.pick(Chess.initial, _quiet).uci];
    }

    expect(run(), run());
  });

  test('stronger levels pick good moves (drop < 3 win%) more often', () {
    const good = {'e2e4', 'd2d4', 'g1f3', 'c2c4'};
    double goodRate(int level) {
      final p = _picker(level);
      var hits = 0;
      for (var i = 0; i < 1000; i++) {
        if (good.contains(p.pick(Chess.initial, _quiet).uci)) hits++;
      }
      return hits / 1000;
    }

    final rates = [
      for (final n in [1, 2, 3, 4]) goodRate(n),
    ];
    for (var i = 1; i < rates.length; i++) {
      expect(rates[i], greaterThan(rates[i - 1]), reason: 'rates $rates');
    }
    expect(rates.first, lessThan(0.5), reason: 'rates $rates');
    expect(rates.last, greaterThan(0.75), reason: 'rates $rates');
  });

  test('weak levels make big blunders, level 4 almost never', () {
    expect(_bigBlunderRate(_picker(1)), greaterThan(0.08));
    expect(_bigBlunderRate(_picker(2)), greaterThan(0.03));
    expect(_bigBlunderRate(_picker(4)), lessThan(0.02));
  });

  test('never two big blunders in a row', () {
    final p = _picker(1, 5);
    var previous = false;
    for (var i = 0; i < 3000; i++) {
      final pick = p.pick(Chess.initial, _quiet);
      expect(previous && pick.bigBlunder, isFalse, reason: 'pick $i');
      previous = pick.bigBlunder;
    }
  });

  test('mate in one: levels 3-4 almost always see it, 1-2 often miss', () {
    final rates = {
      for (final n in [1, 2, 3, 4])
        n: _rate(_picker(n), _backRank, _mateInOne, 'a1a8'),
    };
    expect(rates[1], lessThan(0.6), reason: '$rates');
    expect(rates[2], lessThan(0.85), reason: '$rates');
    expect(rates[3], greaterThan(0.93), reason: '$rates');
    expect(rates[4], greaterThan(0.97), reason: '$rates');
  });

  test('a big blunder is a drop of at least 30 win% from the best', () {
    final best = winPercent(cp: 30);
    final p = _picker(1, 3);
    for (var i = 0; i < 500; i++) {
      final pick = p.pick(Chess.initial, _quiet);
      final c = _quiet.where((c) => c.uci == pick.uci).firstOrNull;
      if (c == null) {
        expect(pick.bigBlunder, isTrue, reason: 'unscored move ${pick.uci}');
      } else {
        final drop = best - winPercent(cp: c.cp, mate: c.mate);
        expect(pick.bigBlunder, drop >= 30, reason: pick.uci);
      }
    }
  });
}
