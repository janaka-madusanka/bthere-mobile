enum AutoCancelState {
  none,
  cancelsSoon,
  heldArrived,
  heldCodeTried,
  overdue,
  autoCancelled,
}

DateTime? autoCancelInstant(Object? value) {
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

AutoCancelState bookingAutoCancelState(
  Map<String, dynamic> booking,
  DateTime now,
) {
  final status = booking['status'] ?? booking['jobStatus'];
  if (status == 'CANCELLED') {
    final cancellation = booking['cancellation'];
    return cancellation is Map &&
            cancellation['automatic'] == true &&
            cancellation['cancelledBy'] == 'SYSTEM'
        ? AutoCancelState.autoCancelled
        : AutoCancelState.none;
  }
  if (status != 'CONFIRMED' || booking['actualStartedAt'] != null) {
    return AutoCancelState.none;
  }
  final deadline = autoCancelInstant(booking['autoCancelAt']);
  if (deadline == null) return AutoCancelState.none;
  if (!deadline.isAfter(now)) return AutoCancelState.overdue;
  if (booking['autoCancelHold'] == 'PROVIDER_ARRIVED') {
    return AutoCancelState.heldArrived;
  }
  if (booking['autoCancelHold'] == 'START_CODE_TRIED') {
    return AutoCancelState.heldCodeTried;
  }
  if (booking['autoCancelHold'] != null) return AutoCancelState.none;
  final start = autoCancelInstant(booking['startDatetimeUtc']);
  return start != null && !start.isAfter(now)
      ? AutoCancelState.cancelsSoon
      : AutoCancelState.none;
}
