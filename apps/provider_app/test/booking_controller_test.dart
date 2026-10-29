import 'dart:async';

import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/session/app_session_state.dart';
import 'package:provider_app/features/bookings/application/booking_controller.dart';
import 'package:provider_app/features/bookings/data/booking_journal.dart';
import 'package:provider_app/features/bookings/data/booking_repository.dart';
import 'package:provider_app/features/bookings/domain/booking_models.dart';

import 'booking_api_test.dart' show offerJson, bookingJson;
import 'provider_account_test.dart' show accountSession;
import 'service_draft_store_test.dart' show MemoryDraftStorage;
import 'support/fake_session_storage.dart';

class FakeBookings extends BookingRepository {
  FakeBookings()
    : super(
        ApiClient(
          config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
        ),
      );
  List<BookingOffer> pending = [BookingOffer.fromJson(offerJson())];
  List<BookingEvent> updates = [];
  AssignedBooking assigned = AssignedBooking.fromJson(bookingJson());
  int decisions = 0;
  Completer<BookingDecision>? response;
  bool failOffers = false;
  @override
  Future<List<BookingOffer>> offers() async {
    if (failOffers) throw StateError('offline');
    return pending;
  }

  @override
  Future<List<BookingEvent>> events(int after) async =>
      updates.where((e) => e.id > after).toList();
  @override
  Future<AssignedBooking> booking(int id) async => assigned;
  @override
  Future<BookingDecision> decide(int offerId, {required bool accept}) async {
    decisions++;
    pending = [];
    return response == null
        ? BookingDecision.fromJson({
            'requestId': 501,
            'jobId': accept ? 70 : null,
            'status': 'AWAITING_CUSTOMER_CONFIRMATION',
          })
        : await response!.future;
  }
}

void main() {
  late FakeBookings repository;
  late BookingJournal journal;
  late ProviderContainer container;
  var now = testNow;
  ProviderContainer create() => ProviderContainer(
    overrides: [
      bookingRepositoryProvider.overrideWithValue(repository),
      bookingJournalProvider.overrideWithValue(journal),
      sessionStorageProvider.overrideWithValue(
        FakeSessionStorage()..session = accountSession(),
      ),
      appSessionStateProvider.overrideWith(
        (ref) async => AppSessionState.authenticated,
      ),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  setUp(() {
    now = testNow;
    repository = FakeBookings();
    journal = BookingJournal(MemoryDraftStorage());
    container = create();
  });
  tearDown(() {
    container.dispose();
    repository.client.close(force: true);
  });
  test('accept persists job reference, restores after restart, and never implies paid service', () async {
    final state = await container.read(bookingControllerProvider.future);
    expect(
      await container
          .read(bookingControllerProvider.notifier)
          .decide(state.offers.single, accept: true),
      isTrue,
    );
    expect((await journal.read(12)).jobs, {70});
    expect(
      container
          .read(bookingControllerProvider)
          .requireValue
          .bookings
          .single
          .canStart,
      isFalse,
    );
    container.dispose();
    container = create();
    expect(
      (await container.read(bookingControllerProvider.future))
          .bookings
          .single
          .id,
      70,
    );
  });
  test('expiry and duplicate taps do not send extra mutations', () async {
    final state = await container.read(bookingControllerProvider.future);
    final controller = container.read(bookingControllerProvider.notifier);
    repository.response = Completer<BookingDecision>();
    final first = controller.decide(state.offers.single, accept: true);
    expect(await controller.decide(state.offers.single, accept: true), isFalse);
    repository.response!.complete(
      BookingDecision.fromJson({
        'requestId': 501,
        'jobId': 70,
        'status': 'AWAITING_PAYMENT',
      }),
    );
    await first;
    expect(repository.decisions, 1);
    now = now.add(const Duration(minutes: 2));
    expect(await controller.decide(state.offers.single, accept: true), isFalse);
    expect(repository.decisions, 1);
  });
  test(
    'revoked offers disappear; failed reconciliation does not advance cursor',
    () async {
      await container.read(bookingControllerProvider.future);
      repository.pending = [];
      repository.updates = [
        BookingEvent.fromJson({
          'eventId': 4,
          'requestId': 501,
          'eventType': 'OFFER_CANCELLED',
        }),
      ];
      final controller = container.read(bookingControllerProvider.notifier);
      repository.failOffers = true;
      await controller.refresh();
      expect((await journal.read(12)).after, 0);
      expect(
        container.read(bookingControllerProvider).requireValue.offers,
        isEmpty,
      );
      repository.failOffers = false;
      await controller.refresh();
      expect((await journal.read(12)).after, 4);
      expect(
        container.read(bookingControllerProvider).requireValue.offers,
        isEmpty,
      );
    },
  );
}
