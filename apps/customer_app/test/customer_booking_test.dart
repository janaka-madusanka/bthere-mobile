import 'dart:async';
import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/auth/data/customer_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booking_fixture.dart';
import 'customer_discovery_test.dart' show waitForState;

void main() {
  test('request cancellation keeps the confirmed server result and cannot cancel funded bookings', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
    c.stage = BookingStage.created;
    await c.cancelCreatedRequest();
    expect(c.created!['status'], 'CANCELLED');
    expect(c.created!['requestId'], 501);
    final count = f.f.adapter.requests
        .where((r) => r.path.endsWith('/501/cancel'))
        .length;
    c.created = {
      ...c.created!,
      'status': 'CONFIRMED',
      'paymentStatus': 'RESERVED',
    };
    await c.cancelCreatedRequest();
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/501/cancel')).length,
      count,
    );
  });
  test('unconfirmed payment response never becomes a success or failure result screen', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
    f.walletConfirmationStatus = 503;
    c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
    c.stage = BookingStage.created;
    await c.confirmRequestWallet();
    expect(c.error, isNotNull);
    expect(c.paymentOutcome, isNull);
    expect(c.created!['requestId'], 501);
  });
  test('pending, matching and unconfirmed wallet states never report payment success', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
    expect(c.paymentOutcome, isNull);
    c.payment = {'status': 'PENDING'};
    expect(c.paymentOutcome, isNull);
    c.created = {
      ...c.created!,
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
      'paymentStatus': 'NOT_STARTED',
    };
    expect(c.paymentOutcome, isNull);
    c.created = {
      ...c.created!,
      'status': 'CONFIRMED',
      'paymentStatus': 'RESERVED',
    };
    expect(c.paymentOutcome, 'SUCCESS');
  });

  test('changing an unpaid failed request cancels it before returning to payment choices', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    c.created = {
      ...f.requestViewBody,
      'status': 'AWAITING_CUSTOMER_CONFIRMATION',
      'paymentMethod': 'WALLET',
    };
    c.stage = BookingStage.created;
    c.paymentFailureReason = 'Insufficient available wallet balance';
    await c.changeRequestPaymentMethod();
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/501/cancel')),
      hasLength(1),
    );
    expect(c.created, isNull);
    expect(c.method, isNull);
    expect(c.stage, BookingStage.review);
    expect(c.paymentOutcome, isNull);
  });
  test('wallet confirmation repository contract', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    await f.journey.repository.confirmRequestWallet(501);
  });
  test('request wallet payment waits for acceptance and confirmation retries never reserve twice', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final c = f.journey;
    c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
    c.stage = BookingStage.created;
    await c.pay();
    expect(c.error, contains('after a provider accepts'));
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      isEmpty,
    );
    f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
    await c.pay();
    expect(c.error, isNull);
    expect(c.created!['paymentStatus'], 'RESERVED');
    expect(c.created!['status'], 'CONFIRMED');
    final request = f.f.adapter.requests.singleWhere(
      (r) => r.path.endsWith('/confirm-wallet'),
    );
    expect(request.data, isNull);
    await c.pay();
    expect(
      f.f.adapter.requests.where((r) => r.path.endsWith('/confirm-wallet')),
      hasLength(1),
    );
  });

  test('insufficient request wallet funds retain the same request for an explicit retry', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    f.requestViewBody['status'] = 'AWAITING_CUSTOMER_CONFIRMATION';
    f.walletConfirmationStatus = 409;
    final c = f.journey;
    c.created = {...f.requestViewBody, 'paymentMethod': 'WALLET'};
    c.stage = BookingStage.created;
    await c.confirmRequestWallet();
    expect(c.error, 'Insufficient available wallet balance');
    expect(c.created!['requestId'], 501);
    expect(c.stage, BookingStage.created);
    f.walletConfirmationStatus = 200;
    await c.confirmRequestWallet();
    expect(c.created!['paymentStatus'], 'RESERVED');
    expect(c.error, isNull);
  });
  test('direct request chooses provider before questions and preserves that choice while answering', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(
      fields: [fieldJson(id: 20, type: 'TEXT', required: true)],
    );
    addTearDown(f.dispose);
    await f.start();
    f.input();
    final c = f.journey;
    c.languages.add('ENGLISH');
    c.skills.add(10);
    await c.nextServiceDetails();
    expect(c.stage, BookingStage.results);
    expect(c.answers, isEmpty);
    c.continueWithProviders();
    expect(c.stage, BookingStage.results);
    c.select(c.candidates.single);
    c.continueWithProviders();
    expect(c.stage, BookingStage.serviceDetails);
    c.continueServiceDetails();
    expect(c.fieldErrors, isNotEmpty);
    c.answer(c.context!.fields.single, 'Patient details');
    expect(c.selected.keys, [15]);
    expect(c.searchResult?['status'], 'AVAILABLE');
    c.continueServiceDetails();
    expect(c.stage, BookingStage.review);
    expect(c.bookingInput()['providerId'], 15);
    c.backToServiceDetails();
    c.backFromServiceDetails();
    expect(c.stage, BookingStage.results);
    c.edit(() => c.radius = 12);
    expect(c.stage, BookingStage.details);
    expect(c.selected, isEmpty);
  });

  test('open request skips provider selection and submits matching request without provider IDs', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(
      selectionMode: 'OPEN_REQUEST',
      methods: ['WALLET'],
      fields: [fieldJson(id: 20, type: 'TEXT', required: true)],
    );
    f.policyBody = {
      'enabled': true,
      'minimumNoticeMinutes': 30,
      'maximumRadiusKm': 50,
    };
    addTearDown(f.dispose);
    await f.start();
    f.input();
    final c = f.journey;
    c.method = 'WALLET';
    c.languages.add('ENGLISH');
    c.skills.add(10);
    await c.nextServiceDetails();
    expect(c.stage, BookingStage.serviceDetails);
    expect(c.selected, isEmpty);
    c.answer(c.context!.fields.single, 'Patient details');
    c.continueServiceDetails();
    expect(c.stage, BookingStage.review);
    final booking = c.bookingInput();
    expect(booking.containsKey('providerId'), isFalse);
    expect(booking.containsKey('providerIds'), isFalse);
    await c.submit();
    expect(c.error, isNull);
    expect(c.created?['requestId'], 501);
    final request = f.f.adapter.requests.singleWhere(
      (r) => r.path == '/customers/me/booking-requests',
    );
    expect(request.headers['Idempotency-Key'], isNotEmpty);
    expect((request.data as Map)['booking'], booking);
    expect(
      f.f.adapter.requests.where((r) => r.path == '/customers/me/bookings'),
      isEmpty,
    );
  });

  test('scheduled request timeout retains the same durable key for an explicit retry', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(
      selectionMode: 'OPEN_REQUEST',
      methods: ['WALLET'],
    );
    f.policyBody = {
      'enabled': true,
      'minimumNoticeMinutes': 0,
      'maximumRadiusKm': 50,
    };
    addTearDown(f.dispose);
    await f.start();
    f.input();
    final c = f.journey;
    c.method = 'WALLET';
    c.languages.add('ENGLISH');
    c.skills.add(10);
    await c.nextServiceDetails();
    c.continueServiceDetails();
    f.requestCreateStatus = 503;
    await c.submit();
    expect(c.uncertain, isTrue);
    final first = f.f.adapter.requests.singleWhere(
      (r) => r.path == '/customers/me/booking-requests',
    );
    c.uncertain = false;
    f.requestCreateStatus = 201;
    await c.submit();
    final requests = f.f.adapter.requests
        .where((r) => r.path == '/customers/me/booking-requests')
        .toList();
    expect(requests, hasLength(2));
    expect(
      requests.last.headers['Idempotency-Key'],
      first.headers['Idempotency-Key'],
    );
    expect(c.created?['requestId'], 501);
  });
  test('known service requirements open before filter validation or provider search', () async {
    final f = BookingFixture()..autoAvailability = true;
    addTearDown(f.dispose);
    f.requirementBody = [requirementJson()];
    f.eligibility = {'eligible': false, 'reasons': []};
    await f.start();
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.serviceDetails);
    expect(f.journey.requirements, hasLength(1));
    expect(f.journey.fieldErrors, isEmpty);
    expect(
      f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
      isEmpty,
    );
    f.journey.requirementAnswer(
      f.journey.requirements.single.field,
      'Home care detail',
    );
    f.requirementBody = [
      requirementJson(value: 'Home care detail', status: 'PENDING'),
    ];
    await f.journey.saveRequirements();
    expect(f.journey.allowed, isFalse);
    expect(f.journey.requirements.single.status, 'PENDING');
    f.requirementBody = [
      requirementJson(value: 'Home care detail', status: 'APPROVED'),
    ];
    f.eligibility = {'eligible': true, 'reasons': []};
    f.journey.radius = 12;
    await f.journey.refreshRequirements();
    expect(f.journey.allowed, isTrue);
    expect(f.journey.requirements.single.status, 'APPROVED');
    expect(f.journey.radius, 12);
    expect(f.journey.stage, BookingStage.serviceDetails);
  });
  test(
    'filter edits debounce availability without advancing or blocking input',
    () async {
      final f = BookingFixture()
        ..autoAvailability = true
        ..availabilityDebounce = const Duration(milliseconds: 10);
      addTearDown(f.dispose);
      await f.start();
      f.input();
      final c = f.journey;
      c.edit(() => c.radius = 6);
      c.edit(() => c.radius = 7);
      c.edit(() => c.radius = 8);
      expect(c.checkingAvailability, isTrue);
      expect(c.busy, isFalse);
      await waitForState(c, () => !c.checkingAvailability);
      final requests = f.f.adapter.requests.where(
        (r) => r.path.contains('/provider-search'),
      );
      expect(requests, hasLength(1));
      expect((requests.single.data as Map)['radiusKm'], 8);
      expect(c.availabilityLabel, '1 provider available');
      expect(c.stage, BookingStage.details);
      f.candidateRows = [];
      c.edit(() => c.languages.add('ENGLISH'));
      await waitForState(c, () => !c.checkingAvailability);
      expect(c.availabilityLabel, 'No providers available');
      expect(c.availableCandidates, isEmpty);
    },
  );

  test('obsolete availability response cannot replace newer filters', () async {
    final f = BookingFixture()
      ..autoAvailability = true
      ..availabilityDebounce = const Duration(milliseconds: 10);
    addTearDown(f.dispose);
    await f.start();
    f.input();
    final c = f.journey;
    final old = Completer<void>();
    f.pendingSearch = old;
    c.edit(() => c.radius = 8);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    f.pendingSearch = null;
    f.candidateRows = [];
    c.edit(() => c.radius = 12);
    await waitForState(c, () => !c.checkingAvailability);
    expect(c.availabilityLabel, 'No providers available');
    f.candidateRows = [candidateJson()];
    old.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.availabilityLabel, 'No providers available');
    expect(c.radius, 12);
  });

  test(
    'availability failure offers retry instead of claiming zero providers',
    () async {
      final f = BookingFixture()
        ..autoAvailability = true
        ..availabilityDebounce = const Duration(milliseconds: 10);
      addTearDown(f.dispose);
      await f.start();
      f.input();
      f.searchStatus = 503;
      f.searchError = {'message': 'Unavailable'};
      final c = f.journey;
      c.edit(() => c.radius = 8);
      await waitForState(c, () => !c.checkingAvailability);
      expect(c.availabilityError, isNotNull);
      expect(c.availabilityLabel, isNull);
      f.searchStatus = 200;
      f.searchError = null;
      c.retryAvailability();
      await waitForState(c, () => !c.checkingAvailability);
      expect(c.availabilityError, isNull);
      expect(c.availableCandidates, hasLength(1));
    },
  );
  test('insufficient team availability does not claim zero providers or open booking questions', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    f.contextBody = contextJson(count: 2);
    f.candidateRows = [];
    f.candidateTotal = 1;
    await f.start();
    f.input();
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.details);
    expect(f.journey.availabilityLabel, 'Not enough providers available');
    expect(f.journey.error, isNull);
    expect(
      f.journey.availabilityNotice,
      'More providers are needed for this booking',
    );
  });

  test('availability pagination adds map pins and counts distinct providers without inflating locations', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    f.hasNext = true;
    f.candidateTotal = 3;
    await f.start();
    f.input();
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    await f.enterServiceDetails();
    expect(f.journey.availabilityLabel, '1+ providers available');
    f.candidateRows = [
      candidateJson(id: 16),
      candidateJson(id: 15, location: 9),
    ];
    f.hasNext = false;
    await f.journey.loadMoreAvailableProviders();
    expect(f.journey.availableCandidates, hasLength(3));
    expect(f.journey.availabilityLabel, '2 providers available');
    expect(f.journey.stage, BookingStage.serviceDetails);
    expect(f.journey.hasMoreAvailableProviders, isFalse);
  });

  test('Continue checks selected range and filters before booking questions and retains backend markers', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    f.contextBody = contextJson(fields: [fieldJson(required: true)]);
    f.candidateRows = [
      {
        ...candidateJson(),
        'mapMarker': {
          'icon': {'url': 'https://example.invalid/provider.svg'},
        },
      },
    ];
    await f.start();
    f.input();
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    f.journey.radius = 12;
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.serviceDetails);
    expect(f.journey.availabilityLabel, '1 provider available');
    expect(
      f.journey.availableCandidates.single.markerIcon,
      'https://example.invalid/provider.svg',
    );
    final request = f.f.adapter.requests.lastWhere(
      (r) => r.path.contains('/provider-search'),
    );
    expect((request.data as Map)['radiusKm'], 12);
    expect((request.data as Map)['languages'], ['ENGLISH']);
    expect((request.data as Map).containsKey('answers'), isFalse);
    f.journey.answer(f.journey.context!.fields.single, 'Patient care notes');
    expect(f.journey.availabilityLabel, '1 provider available');
    f.journey.edit(() => f.journey.radius = 15);
    expect(f.journey.availability, isNull);
    expect(f.journey.availableCandidates, isEmpty);
  });

  test('no available providers keeps the customer on filters without opening the booking form', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    f.candidateRows = [];
    await f.start();
    f.input();
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.details);
    expect(f.journey.availabilityLabel, 'No providers available');
    expect(f.journey.error, isNull);
    expect(f.journey.availabilityNotice, 'No matching providers just yet');
    expect(f.journey.availableCandidates, isEmpty);
    expect(
      f.f.adapter.requests.where((r) => r.path == '/customers/me/bookings'),
      isEmpty,
    );
  });

  test('entering Service Details refreshes new backend fields and preserves unchanged answers', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    f.contextBody = contextJson(
      fields: [fieldJson(id: 20, code: 'EXISTING', type: 'TEXT')],
    );
    await f.start();
    f.input();
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    f.journey.answers['EXISTING'] = 'Retain this answer';
    f.contextBody = contextJson(
      fields: [
        fieldJson(id: 20, code: 'EXISTING', type: 'TEXT'),
        fieldJson(
          id: 21,
          code: 'NEW_ADMIN_FIELD',
          type: 'TEXT',
          required: true,
        ),
      ],
    );
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.serviceDetails);
    expect(
      f.journey.context!.fields.map((field) => field.code),
      contains('NEW_ADMIN_FIELD'),
    );
    expect(f.journey.answers['EXISTING'], 'Retain this answer');
    expect(f.journey.languages, contains('ENGLISH'));
    expect(f.journey.skills, contains(10));
    expect(f.journey.busy, isFalse);
  });

  test(
    'Continue requires every displayed preference and accepts false and zero',
    () async {
      final f = BookingFixture();
      addTearDown(f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 51,
          'label': 'Spoken languages',
          'fieldType': 'MULTI_SELECT',
          'filterOperator': 'IN',
          'options': ['ENGLISH', 'SINHALA'],
        },
        {
          'fieldId': 52,
          'label': 'Gender',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['MALE', 'FEMALE'],
        },
        {
          'fieldId': 53,
          'label': 'Experience',
          'fieldType': 'NUMBER',
          'filterOperator': 'RANGE',
        },
        {
          'fieldId': 54,
          'label': 'Transport',
          'fieldType': 'BOOLEAN',
          'filterOperator': 'EQUALS',
        },
      ];
      await f.start();
      f.input();
      await f.enterServiceDetails();
      expect(f.journey.stage, BookingStage.details);
      expect(
        f.journey.fieldErrors.keys,
        containsAll([
          'Spoken languages',
          'Gender',
          'Experience',
          'Transport',
          'Skills',
        ]),
      );
      f.journey.providerFilters.addAll({
        51: ['ENGLISH'],
        52: ['FEMALE'],
        53: {'minimum': 0},
        54: false,
      });
      f.journey.skills.add(10);
      await f.enterServiceDetails();
      expect(f.journey.fieldErrors, isEmpty);
      expect(f.journey.stage, BookingStage.serviceDetails);
      f.journey.edit(() => f.journey.providerFilters[51] = []);
      await f.enterServiceDetails();
      expect(f.journey.fieldErrors, contains('Spoken languages'));
      expect(
        f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
        hasLength(1),
      );
    },
  );

  test(
    'legacy language and skills must be selected before continuing',
    () async {
      final f = BookingFixture();
      addTearDown(f.dispose);
      await f.start();
      f.input();
      await f.enterServiceDetails();
      expect(f.journey.fieldErrors.keys, containsAll(['Language', 'Skills']));
      f.journey.languages.add('ENGLISH');
      f.journey.skills.add(10);
      await f.enterServiceDetails();
      expect(f.journey.stage, BookingStage.serviceDetails);
    },
  );

  test('initial schedule uses the next current quarter hour in the market timezone', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    final start = MarketTime.parse(f.journey.start, f.journey.context!.zone);
    expect(start.minute % 15, 0);
    expect(
      start.difference(f.journey.now()).inSeconds,
      inInclusiveRange(1, 900),
    );
    expect(
      DateTime.parse(f.journey.end).difference(DateTime.parse(f.journey.start)),
      const Duration(hours: 6),
    );
  });
  test('empty location and schedule report actionable field errors before navigation', () async {
    final f = BookingFixture();
    addTearDown(f.dispose);
    await f.start();
    f.journey.point = null;
    f.journey.start = f.journey.end = '';
    await f.enterServiceDetails();
    expect(f.journey.stage, BookingStage.details);
    expect(
      f.journey.fieldErrors.keys,
      containsAll(['Location', 'Start time', 'Duration']),
    );
    expect(f.journey.error, 'Complete the highlighted details to continue.');
    expect(
      f.f.adapter.requests.where((r) => r.path.contains('/provider-search')),
      isEmpty,
    );
  });

  test(
    'resolved marker ignores gender rules, profile photo and cover assets',
    () {
      final row = candidateJson();
      row['mapMarker'] = {
        'source': 'COMBINATION',
        'icon': {'url': 'https://cdn.example.com/car.svg'},
        'conditions': [
          {'fieldId': 45, 'choiceValue': 'CAR'},
        ],
      };
      expect(
        ProviderCandidate.parse(row).markerIcon,
        'https://cdn.example.com/car.svg',
      );
      row['mapMarker'] = {'source': 'DEFAULT', 'icon': null};
      expect(ProviderCandidate.parse(row).markerIcon, isNull);
      row['mapMarker'] = {
        'icon': {'url': 'javascript:bad'},
      };
      expect(ProviderCandidate.parse(row).markerIcon, isNull);
    },
  );
  test('pricing discovery validates IDs against configured choice filters', () {
    final body = contextJson();
    body['providerFilters'] = [
      {
        'fieldId': 45,
        'label': 'Care level',
        'fieldType': 'SELECT',
        'filterOperator': 'IN',
        'options': ['BASIC', 'SPECIALIST'],
      },
    ];
    body['pricingFieldIds'] = [45];
    expect(
      BookingContext.parse(body, const BookingKey(1, 3, 12)).pricingFieldIds,
      [45],
    );
    for (final ids in [
      [45, 45],
      [47],
      ['45'],
    ]) {
      body['pricingFieldIds'] = ids;
      expect(
        () => BookingContext.parse(body, const BookingKey(1, 3, 12)),
        throwsFormatException,
      );
    }
  });
  test(
    'quote and booking share final pricing choices, search keeps filter arrays',
    () async {
      final f = BookingFixture();
      addTearDown(f.dispose);
      f.contextBody['providerFilters'] = [
        {
          'fieldId': 45,
          'label': 'Care level',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['BASIC', 'SPECIALIST'],
        },
        {
          'fieldId': 47,
          'label': 'Gender',
          'fieldType': 'SELECT',
          'filterOperator': 'IN',
          'options': ['MALE', 'FEMALE'],
        },
      ];
      f.contextBody['pricingFieldIds'] = [45];
      await f.start();
      f.input();
      f.journey.providerFilters[45] = ['BASIC', 'SPECIALIST'];
      f.journey.providerFilters[47] = ['FEMALE'];
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      expect(() => f.journey.bookingInput(), throwsA(isA<BookingProblem>()));
      f.journey.choosePricing(45, 'SPECIALIST');
      final payload = f.journey.bookingInput();
      expect(payload['pricingSelections'], [
        {'fieldId': 45, 'choiceValue': 'SPECIALIST'},
      ]);
      expect(payload['answers'], isEmpty);
      expect(payload.containsKey('providerFilters'), isFalse);
      await f.journey.previewQuote();
      expect(f.journey.quote?['expectedAmount'], 2400);
      final quoted = f.f.adapter.requests.lastWhere(
        (r) => r.path.endsWith('/bookings/quote'),
      );
      expect(quoted.data, payload);
      expect(f.bookings, isEmpty);
      final area = f.f.adapter.requests.lastWhere(
        (r) => r.path.contains('/booking-context'),
      );
      expect(Uri.parse(area.path).queryParameters['pricingLatitude'], '6.9271');
      expect(
        Uri.parse(area.path).queryParameters['pricingLongitude'],
        '79.8612',
      );
      f.journey.choosePricing(45, 'BASIC');
      expect(f.journey.quote, isNull);
      await f.journey.previewQuote();
      await f.journey.submit();
      final booked = f.f.adapter.requests.lastWhere(
        (r) => r.path == '/customers/me/bookings' && r.method == 'POST',
      );
      expect(
        booked.data,
        f.f.adapter.requests
            .lastWhere((r) => r.path.endsWith('/bookings/quote'))
            .data,
      );
    },
  );
  test(
    'quote error remains retryable without uncertain booking or job creation',
    () async {
      final f = BookingFixture();
      addTearDown(f.dispose);
      await f.start();
      f.input();
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      f.quoteStatus = 409;
      f.quoteBody = {'detail': 'Rate changed'};
      await f.journey.previewQuote();
      expect(f.journey.error, 'Rate changed');
      expect(f.journey.quote, isNull);
      expect(f.journey.uncertain, isFalse);
      expect(f.bookings, isEmpty);
      f.quoteStatus = 200;
      f.quoteBody = {'expectedAmount': -1, 'currencyCode': 'LKR'};
      await f.journey.previewQuote();
      expect(f.journey.quote, isNull);
      expect(f.journey.error, contains('unsupported response'));
    },
  );

  test('booking field icons use backend list assets without substituting map markers', () {
    final field = BookingField.parse({
      ...fieldJson(),
      'icon': {'url': 'https://example.invalid/bed.svg'},
      'mapMarkerIcon': {'url': 'https://example.invalid/map.svg'},
    });
    expect(field.iconUrl, 'https://example.invalid/bed.svg');
    expect(BookingField.parse(fieldJson()).iconUrl, isNull);
  });
  test('configured provider filters use typed search values and never become booking answers', () async {
    final f = BookingFixture();
    f.contextBody['providerFilters'] = [
      {
        'fieldId': 25,
        'label': 'Gender',
        'fieldType': 'SELECT',
        'filterOperator': 'IN',
        'options': [
          {'value': 'FEMALE', 'label': 'Female'},
          'MALE',
        ],
      },
      {
        'fieldId': 26,
        'label': 'Experience',
        'fieldType': 'NUMBER',
        'filterOperator': 'RANGE',
      },
      {
        'fieldId': 27,
        'label': 'Own vehicle',
        'fieldType': 'BOOLEAN',
        'filterOperator': 'EQUALS',
      },
    ];
    await f.start();
    addTearDown(f.dispose);
    f.input();
    f.journey.providerFilters.addAll({
      25: ['FEMALE'],
      26: {'minimum': '0', 'maximum': '5.5'},
      27: false,
    });
    expect(f.journey.searchInput()['providerFilters'], [
      {
        'fieldId': 25,
        'value': ['FEMALE'],
      },
      {'fieldId': 26, 'minimum': 0, 'maximum': 5.5},
      {'fieldId': 27, 'value': false},
    ]);
    await f.journey.search();
    f.journey.select(f.journey.candidates.single);
    expect(f.journey.bookingInput().containsKey('providerFilters'), isFalse);
    expect(f.journey.bookingInput()['answers'], isEmpty);
    await f.journey.load();
    expect(f.journey.providerFilters, isEmpty);
  });
  test('provider filter invalid choices and ranges are rejected locally', () {
    final number = BookingProviderFilter.parse({
      'fieldId': 1,
      'label': 'Experience',
      'fieldType': 'NUMBER',
      'filterOperator': 'RANGE',
    });
    for (final range in [
      {'minimum': 'NaN'},
      {'minimum': 5, 'maximum': 1},
    ]) {
      expect(() => number.serialize(range), throwsA(isA<BookingProblem>()));
    }
    expect(number.serialize({'minimum': '', 'maximum': ''}), isNull);
    final choice = BookingProviderFilter.parse({
      'fieldId': 2,
      'label': 'Vehicle',
      'fieldType': 'MULTI_SELECT',
      'filterOperator': 'IN',
      'options': ['CAR'],
    });
    expect(() => choice.serialize(['VAN']), throwsA(isA<BookingProblem>()));
    expect(
      () => choice.serialize(['CAR', 'CAR']),
      throwsA(isA<BookingProblem>()),
    );
    expect(
      () => BookingProviderFilter.parse({
        'fieldId': 2,
        'label': 'Private',
        'fieldType': 'DOCUMENT_UPLOAD',
        'filterOperator': 'IN',
      }),
      throwsFormatException,
    );
  });
  test(
    'malformed saved upload evidence fails during parsing instead of rendering',
    () {
      expect(
        () => CustomerRequirement.parse(
          requirementJson(
            type: 'DOCUMENT_UPLOAD',
            status: 'PENDING',
            value: {
              'files': ['invalid'],
            },
          ),
        ),
        throwsFormatException,
      );
      final parsed = CustomerRequirement.parse(
        requirementJson(
          type: 'DOCUMENT_UPLOAD',
          status: 'PENDING',
          value: {
            'files': [
              {'key': 'private/evidence.pdf'},
            ],
          },
        ),
      );
      expect(parsed.status, 'PENDING');
    },
  );
  test('schema version changes discard obsolete booking answers', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(fields: [fieldJson()]);
    await f.start();
    addTearDown(f.dispose);
    f.journey.answer(f.journey.context!.fields.single, 'Draft');
    f.contextBody = contextJson(
      fields: [
        {...fieldJson(), 'version': 2},
      ],
    );
    await f.journey.load();
    expect(f.journey.answers, isEmpty);
  });
  test('unavailable payment settings prevent a payment mutation', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(methods: ['CARD']);
    await f.start();
    addTearDown(f.dispose);
    f.input();
    f.journey.method = 'CARD';
    await f.journey.search();
    f.journey.select(f.journey.candidates.single);
    await f.journey.submit();
    f.capStatus = 503;
    await f.journey.pay();
    expect(f.journey.error, isNotNull);
    expect(
      f.f.adapter.requests.where(
        (r) => r.path.endsWith('/card-payment-session'),
      ),
      isEmpty,
    );
    expect(f.journey.created?['paymentStatus'], 'PENDING');
  });
  test('context deduplicates shared fields and rejects foreign identities', () {
    final f = fieldJson();
    final body = contextJson(fields: [f]);
    (body['bookingSchema'] as Map)['commonFields'] = [f];
    expect(
      BookingContext.parse(body, const BookingKey(1, 3, 12)).fields.length,
      1,
    );
    expect(
      () => BookingContext.parse(body, const BookingKey(2, 3, 12)),
      throwsFormatException,
    );
  });
  test('unsupported fields, operators and cyclic conditions fail closed', () {
    expect(
      () => BookingField.parse(fieldJson(type: 'SECRET_FIELD')),
      throwsA(isA<BookingProblem>()),
    );
    expect(
      () => BookingField.parse(
        fieldJson(
          condition: {'fieldCode': 'A', 'operator': 'GREATER_THAN', 'value': 1},
        ),
      ),
      throwsA(isA<BookingProblem>()),
    );
    final body = contextJson(
      fields: [
        fieldJson(code: 'A', condition: {'fieldCode': 'B', 'value': true}),
        fieldJson(
          id: 21,
          code: 'B',
          condition: {'fieldCode': 'A', 'value': true},
        ),
      ],
    );
    expect(
      () => BookingContext.parse(body, const BookingKey(1, 3, 12)),
      throwsA(isA<BookingProblem>()),
    );
  });
  test(
    'typed false and zero are valid and choice labels never become wire values',
    () {
      expect(
        BookingField.parse(fieldJson(type: 'BOOLEAN', required: true))
            .validate(false),
        isNull,
      );
      expect(
        BookingField.parse(fieldJson(type: 'NUMBER', required: true))
            .validate(0),
        isNull,
      );
      final field = BookingField.parse({
        ...fieldJson(type: 'SELECT'),
        'options': [
          {'label': 'At home', 'value': 'HOME'},
        ],
      });
      expect(field.validate('HOME'), isNull);
      expect(field.validate('At home'), isNotNull);
      final child = BookingField.parse(
        fieldJson(condition: {'fieldCode': 'N', 'value': 0}),
      );
      expect(child.applies({'N': '0'}), isFalse);
      expect(child.applies({'N': 0}), isTrue);
      expect(child.applies({}), isFalse);
    },
  );
  test('market wall time serializes offsets without using device timezone', () {
    final date = MarketTime.parse('2030-01-07T08:00:00', 'Asia/Colombo');
    expect(MarketTime.offset(date), '2030-01-07T08:00:00+05:30');
    expect(MarketTime.local(date), '2030-01-07T08:00:00');
    expect(date.toUtc().hour, 2);
    expect(date.toUtc().minute, 30);
  });
  test(
    'nonexistent and ambiguous DST times and crossing intervals are rejected',
    () {
      expect(
        () => MarketTime.parse('2030-03-10T02:30:00', 'America/New_York'),
        throwsA(isA<BookingProblem>()),
      );
      expect(
        () => MarketTime.parse('2030-11-03T01:30:00', 'America/New_York'),
        throwsA(isA<BookingProblem>()),
      );
      expect(
        () => MarketTime.interval(
          MarketTime.parse('2030-03-09T12:00:00', 'America/New_York'),
          MarketTime.parse('2030-03-10T12:00:00', 'America/New_York'),
          DateTime.utc(2030),
        ),
        throwsA(isA<BookingProblem>()),
      );
    },
  );
  test('search sends only documented typed properties and separate booking answers', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(fields: [fieldJson(type: 'NUMBER')]);
    await f.start();
    addTearDown(f.dispose);
    f.input();
    f.journey.answer(f.journey.context!.fields.single, 0);
    f.journey.languages.add('ENGLISH');
    f.journey.skills.add(10);
    await f.journey.search();
    final request = f.f.adapter.requests.lastWhere(
      (r) => r.path == '/customers/me/provider-search',
    );
    expect(request.headers['Authorization'], 'Bearer access-one');
    expect(request.data, {
      'marketId': 1,
      'serviceTypeId': 3,
      'optionId': 12,
      'deliveryMode': 'PROVIDER_TO_CUSTOMER',
      'startAt': '2030-01-07T08:00:00+05:30',
      'endAt': '2030-01-07T10:00:00+05:30',
      'location': {'latitude': 6.9271, 'longitude': 79.8612},
      'radiusKm': 5.0,
      'languages': ['ENGLISH'],
      'requiredSkillIds': [10],
      'page': 0,
      'pageSize': 20,
    });
    f.journey.select(f.journey.candidates.single);
    final booking = f.journey.bookingInput();
    expect(booking['answers'], [
      {'fieldId': 20, 'value': 0},
    ]);
    expect(booking['providerId'], 15);
    expect(booking.containsKey('marketId'), isFalse);
    expect(booking.containsKey('expectedAmount'), isFalse);
    expect(booking['startDatetime'], '2030-01-07T08:00:00');
  });
  test('parent changes clear hidden child answers before submission', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(
      fields: [
        fieldJson(id: 1, code: 'PLACE', type: 'SELECT')
          ..['options'] = ['HOME', 'HOSPITAL'],
        fieldJson(
          id: 2,
          code: 'WARD',
          required: true,
          condition: {'fieldCode': 'PLACE', 'value': 'HOSPITAL'},
        ),
      ],
    );
    await f.start();
    addTearDown(f.dispose);
    final fields = f.journey.context!.fields;
    f.journey.answer(fields.first, 'HOSPITAL');
    f.journey.answer(fields.last, '12');
    f.journey.answer(fields.first, 'HOME');
    expect(f.journey.answers.containsKey('WARD'), isFalse);
  });
  test(
    'ONLINE omits physical data; fixed venue retains candidate location ID',
    () async {
      final f = BookingFixture();
      f.contextBody = contextJson(modes: ['ONLINE', 'CUSTOMER_TO_PROVIDER']);
      await f.start();
      addTearDown(f.dispose);
      f.input();
      f.journey.mode = 'ONLINE';
      final search = f.journey.searchInput();
      expect(search.containsKey('location'), isFalse);
      expect(search.containsKey('radiusKm'), isFalse);
      f.journey.mode = 'CUSTOMER_TO_PROVIDER';
      f.candidateRows = [candidateJson(location: 88)];
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      final input = f.journey.bookingInput();
      expect(input['providerLocationId'], 88);
      expect(input.containsKey('meetingPoint'), isFalse);
    },
  );
  test(
    'route search and booking use distinct pickup/destination schemas',
    () async {
      final f = BookingFixture();
      f.contextBody = contextJson(schedule: 'ROUTE_BASED');
      await f.start();
      addTearDown(f.dispose);
      f.input();
      f.journey.destination = const GeoPoint(7, 79.9);
      f.journey.destinationAddress = 'Test destination';
      final search = f.journey.searchInput();
      expect(search.containsKey('location'), isFalse);
      expect(search.containsKey('endAt'), isFalse);
      expect(search['pickup'], {'latitude': 6.9271, 'longitude': 79.8612});
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      final input = f.journey.bookingInput();
      expect(input['requestedPickupTime'], '2030-01-07T08:00:00');
      expect(input.containsKey('startDatetime'), isFalse);
      expect((input['pickup'] as Map)['address'], 'Test service address');
    },
  );
  test('team selection enforces distinct configured providers and sends providerIds', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(count: 2);
    f.candidateRows = [candidateJson(), candidateJson(id: 16)];
    await f.start();
    addTearDown(f.dispose);
    f.input();
    await f.journey.search();
    f.journey.select(f.journey.candidates.first);
    expect(() => f.journey.bookingInput(), throwsA(isA<BookingProblem>()));
    f.journey.select(f.journey.candidates.last);
    expect(f.journey.bookingInput()['providerIds'], [15, 16]);
    expect(f.journey.bookingInput().containsKey('providerId'), isFalse);
  });
  test(
    'pagination deduplicates provider/location rows and resets after edits',
    () async {
      final f = BookingFixture();
      f.hasNext = true;
      await f.start();
      addTearDown(f.dispose);
      f.input();
      await f.journey.search();
      f.candidateRows = [candidateJson(), candidateJson(id: 16)];
      await f.journey.search(more: true);
      expect(f.journey.candidates.length, 2);
      expect((f.f.adapter.requests.last.data as Map)['page'], 1);
      f.journey.select(f.journey.candidates.first);
      f.journey.edit(() => f.journey.radius = 10);
      expect(f.journey.candidates, isEmpty);
      expect(f.journey.selected, isEmpty);
    },
  );
  test(
    'no candidates is a successful empty state and server errors are not empty',
    () async {
      final f = BookingFixture();
      await f.start();
      addTearDown(f.dispose);
      f.input();
      f.candidateRows = [];
      await f.journey.search();
      expect(f.journey.stage, BookingStage.results);
      expect(f.journey.error, isNull);
      f.searchStatus = 500;
      f.searchError = {'detail': 'Search temporarily unavailable'};
      await f.journey.search();
      expect(f.journey.error, 'Search temporarily unavailable');
    },
  );
  test('requirements save exact dirty entries, preserve false and never set approval', () async {
    final f = BookingFixture();
    f.requirementBody = [requirementJson(type: 'BOOLEAN')];
    f.eligibility = {
      'eligible': false,
      'reasons': [
        {'code': 'MISSING', 'message': 'Complete requirements'},
      ],
    };
    await f.start();
    addTearDown(f.dispose);
    f.journey.requirementAnswer(f.journey.requirements.single.field, false);
    f.requirementBody = [
      requirementJson(type: 'BOOLEAN', value: false, status: 'PENDING'),
    ];
    await f.journey.saveRequirements();
    final request = f.f.adapter.requests.lastWhere(
      (r) => r.path == '/customers/me/requirement-submissions',
    );
    expect(request.method, 'PUT');
    expect(request.data, {
      'submissions': [
        {'requirementId': 1, 'value': false, 'expiresOn': null},
      ],
    });
    expect(f.journey.allowed, isFalse);
    expect(f.journey.requirements.single.status, 'PENDING');
  });
  test('failed requirement save keeps edits and eligibility remains backend controlled', () async {
    final f = BookingFixture();
    f.requirementBody = [requirementJson()];
    await f.start();
    addTearDown(f.dispose);
    f.journey.requirementAnswer(
      f.journey.requirements.single.field,
      'Test detail',
    );
    f.requirementStatus = 400;
    await f.journey.saveRequirements();
    expect(f.journey.requirementAnswers[1], 'Test detail');
    expect(f.journey.dirtyRequirements, {1});
    expect(f.journey.error, isNotNull);
  });
  test(
    'private uploads enforce type and size and use one multipart file',
    () async {
      final f = BookingFixture();
      await f.start();
      addTearDown(f.dispose);
      final field = BookingField.parse({
        ...fieldJson(type: 'DOCUMENT_UPLOAD'),
        'allowedFileTypes': ['PDF'],
        'maximumFileSizeMb': 1,
      });
      final key = await f.journey.upload(
        field,
        Uint8List.fromList('%PDF-'.codeUnits),
        'test.pdf',
      );
      expect(key, 'customers/12/documents/file.pdf');
      final data = f.f.adapter.requests.last.data as FormData;
      expect(data.files.single.key, 'file');
      expect(data.fields, isEmpty);
      await expectLater(
        f.journey.upload(field, Uint8List.fromList([1, 2, 3]), 'fake.pdf'),
        throwsA(isA<BookingProblem>()),
      );
      await expectLater(
        f.journey.upload(field, Uint8List(1024 * 1024 + 1), 'large.pdf'),
        throwsA(isA<BookingProblem>()),
      );
    },
  );
  test(
    'double tap creates exactly one pending booking and no automatic payment',
    () async {
      final f = BookingFixture();
      await f.start();
      addTearDown(f.dispose);
      f.input();
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      final pending = Completer<void>();
      f.pendingBook = pending;
      final first = f.journey.submit();
      await f.journey.submit();
      pending.complete();
      await first;
      expect(
        f.f.adapter.requests
            .where(
              (r) => r.path == '/customers/me/bookings' && r.method == 'POST',
            )
            .length,
        1,
      );
      expect(f.journey.created?['paymentStatus'], 'PENDING');
      expect(f.journey.payment, isNull);
      await f.journey.submit();
      expect(
        f.f.adapter.requests
            .where(
              (r) => r.path == '/customers/me/bookings' && r.method == 'POST',
            )
            .length,
        1,
      );
    },
  );
  test('uncertain booking transport failure blocks retries and preserves history access', () async {
    final f = BookingFixture();
    await f.start();
    addTearDown(f.dispose);
    f.input();
    await f.journey.search();
    f.journey.select(f.journey.candidates.single);
    f.throwBooking = true;
    await f.journey.submit();
    expect(f.journey.uncertain, isTrue);
    await f.journey.submit();
    expect(
      f.f.adapter.requests
          .where(
            (r) => r.path == '/customers/me/bookings' && r.method == 'POST',
          )
          .length,
      1,
    );
    expect(await f.journey.repository.history(), isEmpty);
  });
  test('known availability failure keeps details but requires a fresh provider search', () async {
    final f = BookingFixture();
    await f.start();
    addTearDown(f.dispose);
    f.input();
    await f.journey.search();
    f.journey.select(f.journey.candidates.single);
    f.createStatus = 400;
    await f.journey.submit();
    expect(f.journey.uncertain, isFalse);
    expect(f.journey.selected, isEmpty);
    expect(f.journey.stage, BookingStage.details);
    expect(f.journey.address, 'Test service address');
  });
  test(
    'logout ignores a late search response and clears private draft data',
    () async {
      final f = BookingFixture();
      await f.start();
      addTearDown(f.dispose);
      f.input();
      final pending = Completer<void>();
      f.pendingSearch = pending;
      final searching = f.journey.search();
      await f.f.controller.logout();
      pending.complete();
      await searching;
      expect(f.journey.stage, BookingStage.invalid);
      expect(f.journey.candidates, isEmpty);
      expect(f.journey.address, isEmpty);
    },
  );
  test(
    'cash and wallet payment states are not claimed as paid or settled',
    () async {
      final f = BookingFixture();
      f.contextBody = contextJson(methods: ['WALLET']);
      await f.start();
      addTearDown(f.dispose);
      f.input();
      f.journey.method = 'WALLET';
      await f.journey.search();
      f.journey.select(f.journey.candidates.single);
      await f.journey.submit();
      expect(f.journey.created?['paymentStatus'], 'PENDING');
      await f.journey.pay();
      expect(f.journey.created?['paymentStatus'], 'RESERVED');
      expect(f.journey.payment?['status'], 'POSTED');
    },
  );
  test('card session uses stable key with no card details and mock outcomes are explicit', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(methods: ['CARD']);
    await f.start();
    addTearDown(f.dispose);
    f.input();
    f.journey.method = 'CARD';
    await f.journey.search();
    f.journey.select(f.journey.candidates.single);
    await f.journey.submit();
    await f.journey.pay();
    final request = f.f.adapter.requests.lastWhere(
      (r) => r.path.endsWith('/card-payment-session'),
    );
    expect(request.headers['Idempotency-Key'], 'bthere-card-booking-100');
    expect(request.data, isNull);
    expect(f.journey.created?['paymentStatus'], 'PENDING');
    await f.journey.mockPayment('SUCCESS');
    expect(f.journey.created?['paymentStatus'], 'PAID');
    await f.journey.mockPayment('REFUND');
    expect(f.journey.created?['paymentStatus'], 'REFUNDED');
  });
  test('capability failure does not invent cash if the selected option allows only card', () async {
    final f = BookingFixture();
    f.contextBody = contextJson(methods: ['CARD']);
    f.capStatus = 503;
    await f.start();
    addTearDown(f.dispose);
    expect(f.journey.availableMethods, isEmpty);
    expect(f.journey.paymentError, isNotNull);
  });
  test(
    'unauthorized booking write refreshes once but never replays the mutation',
    () async {
      final f = BookingFixture();
      await f.start();
      addTearDown(f.dispose);
      f.createStatus = 401;
      await expectLater(
        f.journey.repository.book({'paymentMethod': 'CASH'}),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(
        f.f.adapter.requests
            .where(
              (r) => r.path == '/customers/me/bookings' && r.method == 'POST',
            )
            .length,
        1,
      );
      expect(
        f.f.adapter.requests.where((r) => r.path == '/auth/refresh').length,
        1,
      );
    },
  );
}
