import 'dart:convert';

import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bookingJournalProvider = Provider<BookingJournal>(
  (ref) => BookingJournal(const FlutterSecureKeyValueStore()),
);

/// Per-account recovery references only. Never stores answers, codes or money.
class BookingJournal {
  BookingJournal(this.store);
  final SecureKeyValueStore store;
  String _key(int owner) => 'provider_booking_recovery_v1_$owner';
  Future<BookingRecovery> read(int owner) async {
    final raw = await store.read(_key(owner));
    if (raw == null) return const BookingRecovery();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return BookingRecovery(
      after: j['after'] as int,
      jobs: (j['jobs'] as List).cast<int>().toSet(),
    );
  }

  Future<void> write(int owner, BookingRecovery recovery) => store.write(
    _key(owner),
    jsonEncode({'after': recovery.after, 'jobs': recovery.jobs.toList()}),
  );
}

class BookingRecovery {
  const BookingRecovery({this.after = 0, this.jobs = const {}});
  final int after;
  final Set<int> jobs;
}
