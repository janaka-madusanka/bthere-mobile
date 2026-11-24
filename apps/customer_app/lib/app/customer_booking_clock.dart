import 'dart:io' show HttpDate;

/// Server time anchored to monotonic elapsed time, unaffected by phone clock
/// changes after synchronization. HTTP Date has one-second precision.
class CustomerBookingClock {
  CustomerBookingClock(this.fallback, {Duration Function()? elapsed})
    : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration;

  final DateTime Function() fallback;
  final Duration Function() _elapsed;
  DateTime? _server;
  Duration _sampledAt = Duration.zero;

  DateTime now() => _server?.add(_elapsed() - _sampledAt) ?? fallback();

  void synchronize(String? header) {
    if (header == null) return;
    try {
      final server = HttpDate.parse(header).toUtc();
      _server = server;
      _sampledAt = _elapsed();
    } catch (_) {
      // Keep the last valid sample when a response lacks a valid Date header.
    }
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
