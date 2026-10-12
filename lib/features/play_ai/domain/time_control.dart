/// A game's time control: starting time per side plus increment per move.
class TimeControl {
  /// [minutes] per side and [incrementSeconds] added after each move.
  /// `minutes == 0` means no clock.
  const TimeControl.minutes(this.minutes, this.incrementSeconds);

  /// No clock at all.
  static const TimeControl unlimited = TimeControl.minutes(0, 0);

  static const List<TimeControl> presets = [
    unlimited,
    TimeControl.minutes(3, 2),
    TimeControl.minutes(5, 0),
    TimeControl.minutes(10, 0),
    TimeControl.minutes(15, 10),
    TimeControl.minutes(30, 0),
  ];

  final int minutes;
  final int incrementSeconds;

  Duration get initial => Duration(minutes: minutes);
  Duration get increment => Duration(seconds: incrementSeconds);

  bool get isTimed => minutes > 0;

  /// "Unlimited" or "minutes+seconds", e.g. "15+10".
  String get label => isTimed ? '$minutes+$incrementSeconds' : 'Unlimited';

  /// Compact form for storage: `-` for unlimited, else the label.
  String encode() => isTimed ? label : '-';

  /// Inverse of [encode].
  static TimeControl parse(String text) {
    if (text == '-') return unlimited;
    final parts = text.split('+');
    return TimeControl.minutes(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      other.minutes == minutes &&
      other.incrementSeconds == incrementSeconds;

  @override
  int get hashCode => Object.hash(minutes, incrementSeconds);
}
