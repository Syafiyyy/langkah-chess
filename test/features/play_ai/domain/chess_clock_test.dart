import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/play_ai/domain/chess_clock.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  final threePlusTwo = ChessClock.initial(const TimeControl.minutes(3, 2));

  test('starts with the full time on both sides and nothing running', () {
    expect(threePlusTwo.remaining(Side.white, _s(99)), _s(180));
    expect(threePlusTwo.remaining(Side.black, _s(99)), _s(180));
    expect(threePlusTwo.running, isNull);
    expect(threePlusTwo.flagged(_s(999)), isNull);
  });

  test('only the running side loses time, measured from turn start', () {
    final clock = threePlusTwo.start(Side.black, _s(10));
    expect(clock.remaining(Side.black, _s(14.5)), _s(175.5));
    expect(clock.remaining(Side.white, _s(14.5)), _s(180));
  });

  test('a move banks the elapsed time, adds increment and switches', () {
    final clock = threePlusTwo
        .start(Side.black, _s(0))
        .moved(_s(5)); // black used 5 s, gets +2
    expect(clock.running, Side.white);
    expect(clock.remaining(Side.black, _s(100)), _s(177));
    expect(clock.remaining(Side.white, _s(8)), _s(177));
  });

  test('pause freezes the running side; resume continues from there', () {
    final paused = threePlusTwo.start(Side.black, _s(0)).pause(_s(4));
    expect(paused.isPaused, isTrue);
    expect(paused.remaining(Side.black, _s(60)), _s(176));
    expect(paused.flagged(_s(10000)), isNull);

    final resumed = paused.resume(_s(60));
    expect(resumed.isPaused, isFalse);
    expect(resumed.running, Side.black);
    expect(resumed.remaining(Side.black, _s(61)), _s(175));
  });

  test('pause and resume are no-ops when not applicable', () {
    expect(threePlusTwo.pause(_s(1)).isPaused, isFalse);
    final running = threePlusTwo.start(Side.white, _s(0));
    expect(running.resume(_s(5)).remaining(Side.white, _s(5)), _s(175));
  });

  test('flags the running side when its time is used up', () {
    final clock = threePlusTwo.start(Side.white, _s(0));
    expect(clock.flagged(_s(179.9)), isNull);
    expect(clock.flagged(_s(180)), Side.white);
    expect(clock.remaining(Side.white, _s(200)), Duration.zero);
  });

  test('stop banks the time and runs nothing', () {
    final clock = threePlusTwo.start(Side.white, _s(0)).stop(_s(3));
    expect(clock.running, isNull);
    expect(clock.remaining(Side.white, _s(50)), _s(177));
  });

  test('a move made while paused uses no extra time', () {
    final clock = threePlusTwo
        .start(Side.black, _s(0))
        .pause(_s(2))
        .moved(_s(30));
    expect(clock.remaining(Side.black, _s(30)), _s(180));
    expect(clock.running, Side.white);
    expect(clock.isPaused, isTrue);
  });

  test('handOver switches sides without adding increment', () {
    final clock = threePlusTwo
        .start(Side.black, _s(0))
        .handOver(Side.white, _s(3));
    expect(clock.running, Side.white);
    expect(clock.remaining(Side.black, _s(10)), _s(177));
    expect(clock.remaining(Side.white, _s(10)), _s(173));
  });

  test('time until flag is the running side remaining time', () {
    final clock = threePlusTwo.start(Side.white, _s(0));
    expect(clock.timeToFlag(_s(30)), _s(150));
    expect(threePlusTwo.timeToFlag(_s(30)), isNull);
    expect(clock.pause(_s(1)).timeToFlag(_s(30)), isNull);
  });

  test('restores from banked times', () {
    final clock = ChessClock.restore(
      white: _s(50),
      black: _s(60),
      increment: _s(2),
      running: Side.black,
      now: _s(1000),
    );
    expect(clock.remaining(Side.black, _s(1010)), _s(50));
    expect(clock.remaining(Side.white, _s(1010)), _s(50));
  });
}
