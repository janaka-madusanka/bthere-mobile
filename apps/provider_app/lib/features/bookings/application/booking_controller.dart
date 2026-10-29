import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';
import '../../wallet/application/wallet_controller.dart';
import '../data/booking_journal.dart';
import '../data/booking_repository.dart';
import '../domain/booking_models.dart';

class BookingState {
  const BookingState({
    this.offers = const [],
    this.bookings = const [],
    this.busy = false,
    this.error,
  });
  final List<BookingOffer> offers;
  final List<AssignedBooking> bookings;
  final bool busy;
  final String? error;
}

final bookingControllerProvider =
    AsyncNotifierProvider<BookingController, BookingState>(
      BookingController.new,
      dependencies: [
        bookingRepositoryProvider,
        bookingJournalProvider,
        appSessionStateProvider,
        sessionStorageProvider,
        clockProvider,
        walletControllerProvider,
      ],
    );

class BookingController extends AsyncNotifier<BookingState> {
  int? _owner;
  int _epoch = 0;
  bool _working = false;
  BookingRecovery _recovery = const BookingRecovery();
  BookingRepository get _repository => ref.read(bookingRepositoryProvider);
  void _check(int epoch) {
    if (!ref.mounted || epoch != _epoch) throw StateError('Session changed');
  }

  @override
  Future<BookingState> build() async {
    final epoch = ++_epoch;
    ref.onDispose(() => _epoch++);
    _working = false;
    _owner = null;
    if (await ref.watch(appSessionStateProvider.future) !=
        AppSessionState.authenticated) {
      return const BookingState();
    }
    final session = await ref.watch(sessionStorageProvider).read();
    _check(epoch);
    _owner = session?.user?.id;
    if (_owner == null) return const BookingState();
    ref.watch(bookingRepositoryProvider);
    _recovery = await ref.watch(bookingJournalProvider).read(_owner!);
    _check(epoch);
    return _load(epoch);
  }

  Future<BookingState> _load(int epoch) async {
    final events = await _repository.events(_recovery.after);
    _check(epoch);
    // Always reconcile against current offers: a stale push never opens a dialog.
    final offers = await _repository.offers();
    _check(epoch);
    final bookings = <AssignedBooking>[];
    for (final id in _recovery.jobs) {
      try {
        bookings.add(await _repository.booking(id));
      } on NetworkException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      _check(epoch);
    }
    var cursor = _recovery.after;
    for (final event in events) {
      if (event.id > cursor) cursor = event.id;
    }
    if (events.any((e) => e.type == 'BOOKING_COMPLETED')) {
      ref.invalidate(walletControllerProvider);
    }
    final next = BookingRecovery(after: cursor, jobs: _recovery.jobs);
    await ref.read(bookingJournalProvider).write(_owner!, next);
    _check(epoch);
    _recovery = next;
    final now = ref.read(clockProvider)();
    return BookingState(
      offers: offers.where((o) => o.pendingAt(now)).toList(),
      bookings: bookings,
    );
  }

  String _message(Object error) => error is NetworkException
      ? error.message
      : error is FormatException
      ? error.message
      : 'Unable to update bookings. Please retry.';

  Future<void> refresh() async {
    if (_working || _owner == null || state.isLoading) return;
    _working = true;
    final epoch = _epoch;
    final old = state.asData?.value ?? const BookingState();
    try {
      final fresh = await _load(epoch);
      _check(epoch);
      state = AsyncData(fresh);
    } catch (e) {
      if (ref.mounted && epoch == _epoch) {
        // Do not keep ringing when the current server state cannot be verified.
        state = AsyncData(
          BookingState(bookings: old.bookings, error: _message(e)),
        );
      }
    } finally {
      if (epoch == _epoch) _working = false;
    }
  }

  /// Push adapters pass an event ID only; never trust embedded offer/money data.
  Future<void> onPush(int eventId) async {
    if (eventId > _recovery.after) await refresh();
  }

  Future<bool> decide(BookingOffer offer, {required bool accept}) async {
    if (_working || _owner == null || state.isLoading) return false;
    if (!offer.pendingAt(ref.read(clockProvider)())) {
      await refresh();
      return false;
    }
    final epoch = _epoch;
    final owner = _owner!;
    return _mutate(() async {
      final result = await _repository.decide(offer.id, accept: accept);
      _check(epoch);
      if (accept && result.jobId != null) {
        final next = BookingRecovery(
          after: _recovery.after,
          jobs: {..._recovery.jobs, result.jobId!},
        );
        _recovery = next;
        await ref.read(bookingJournalProvider).write(owner, next);
      }
    });
  }

  Future<bool> start(AssignedBooking booking, String code) async {
    if (!booking.canStart) return false;
    return _mutate(() async {
      final result = await _repository.start(booking.id, code);
      if (!result.successful) {
        throw FormatException(
          result.status == 'CODE_LOCKED'
              ? 'Start code locked. Ask your customer to contact support.'
              : 'Incorrect start code. Please try again.',
        );
      }
    });
  }

  Future<bool> complete(AssignedBooking booking) async {
    if (!booking.canComplete) return false;
    return _mutate(() async {
      final result = await _repository.complete(booking.id);
      if (!result.successful) {
        throw const FormatException('Unable to request completion.');
      }
    });
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_working || _owner == null) return false;
    _working = true;
    final epoch = _epoch;
    final old = state.asData?.value ?? const BookingState();
    state = AsyncData(
      BookingState(bookings: old.bookings, offers: old.offers, busy: true),
    );
    try {
      await action();
      _check(epoch);
      final fresh = await _load(epoch);
      _check(epoch);
      state = AsyncData(fresh);
      return true;
    } catch (e) {
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          BookingState(bookings: old.bookings, error: _message(e)),
        );
      }
      return false;
    } finally {
      if (epoch == _epoch) _working = false;
    }
  }
}
