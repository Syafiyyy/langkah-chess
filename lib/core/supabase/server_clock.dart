import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

/// The server's current time, estimated as local wall time plus an offset.
///
/// Samples come from `server_now` in make_move responses (ms precision) and
/// from the HTTP `Date` header of every other response (1 s precision, so it
/// is only used when no precise sample is recent).
class ServerClock {
  ServerClock({DateTime Function()? localNow})
    : _localNow = localNow ?? DateTime.now;

  final DateTime Function() _localNow;
  Duration _offset = Duration.zero;
  DateTime? _lastPreciseAt;

  static const Duration _preciseWins = Duration(seconds: 60);

  Duration get offset => _offset;

  DateTime now() => _localNow().add(_offset);

  void addPreciseSample(DateTime serverNow) {
    final local = _localNow();
    _offset = serverNow.difference(local);
    _lastPreciseAt = local;
  }

  /// [date] is the header's whole second; the real time is within it.
  void addDateHeaderSample(DateTime date) {
    final local = _localNow();
    final precise = _lastPreciseAt;
    if (precise != null && local.difference(precise) < _preciseWins) return;
    _offset = date.add(const Duration(milliseconds: 500)).difference(local);
  }
}

/// RFC 1123 date from an HTTP header, or null.
DateTime? parseHttpDate(String value) {
  try {
    return HttpDate.parse(value);
  } on Exception {
    // HttpException or FormatException, depending on the input.
    return null;
  }
}

/// Feeds the `Date` header of every Supabase response into [clock].
class DateHeaderClient extends http.BaseClient {
  DateHeaderClient(this._clock, [http.Client? inner])
    : _inner = inner ?? http.Client();

  final ServerClock _clock;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final header = response.headers['date'];
    final date = header == null ? null : parseHttpDate(header);
    if (date != null) _clock.addDateHeaderSample(date);
    return response;
  }

  @override
  void close() => _inner.close();
}
