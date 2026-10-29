import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:customer_app/features/booking/application/customer_booking_controller.dart';
import 'package:customer_app/features/booking/data/customer_booking_repository.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';

import 'customer_auth_test.dart' show clock;
import 'customer_discovery_test.dart' show DiscoveryFixture, waitForState;

Map<String, dynamic> fieldJson({
  int id = 20,
  String code = 'CARE_NOTES',
  String type = 'TEXTAREA',
  bool required = false,
  Map<String, Object?>? condition,
}) => {
  'fieldId': id,
  'serviceTypeId': 3,
  'optionId': 12,
  'optionIds': [12],
  'scope': 'BOOKING_FIELD',
  'reuseScope': 'ASSIGNMENT',
  'code': code,
  'label': code.replaceAll('_', ' '),
  'description': null,
  'fieldType': type,
  'required': required,
  'requiresApproval': false,
  'minimumFiles': null,
  'maximumFiles': null,
  'maximumFileSizeMb': null,
  'allowedFileTypes': [],
  'options': null,
  'condition': condition,
  'displayOrder': id,
  'version': 1,
  'status': 'ACTIVE',
};
Map<String, dynamic> contextJson({
  String schedule = 'TIME_BASED',
  List<String> modes = const ['PROVIDER_TO_CUSTOMER'],
  int count = 1,
  String selectionMode = 'DIRECT_REQUEST',
  List<Object?> fields = const [],
  List<String> methods = const ['CASH'],
}) => {
  'marketId': 1,
  'timezone': 'Asia/Colombo',
  'matchingFilters': ['languages', 'requiredSkillIds'],
  'liveTrackingSupported': false,
  'selection': {
    'option': {
      'optionId': 12,
      'serviceTypeId': 3,
      'name': 'Home Care',
      'description': 'Care at home',
      'schedulingModel': schedule,
      'deliveryModes': modes,
      'locationEnabled': true,
      'fulfillmentModel': count > 1
          ? 'ONE_CUSTOMER_MANY_PROVIDERS'
          : 'ONE_TO_ONE',
      'requiredProviderCount': count,
      'providerSelectionMode': selectionMode,
      'allowedPaymentMethods': methods,
      'responsibilities': [],
    },
    'access': {
      'status': 'ELIGIBLE',
      'action': 'CONTINUE',
      'eligibility': {'eligible': true, 'reasons': []},
    },
  },
  'bookingSchema': {
    'serviceTypeId': 3,
    'serviceName': 'Nursing',
    'serviceSetup': {
      'skills': [
        {
          'skillId': 10,
          'name': 'Patient care',
          'required': false,
          'requiresApproval': true,
        },
      ],
      'responsibilities': [],
    },
    'commonFields': [],
    'options': [
      {'optionId': 12, 'code': 'HOME', 'name': 'Home Care', 'fields': fields},
    ],
  },
};
Map<String, dynamic> candidateJson({int id = 15, int? location}) => {
  'providerId': id,
  'assignmentId': id + 100,
  'optionId': 12,
  'providerLocationId': location,
  'displayName': 'Provider $id',
  'profilePhoto': null,
  'averageRating': null,
  'totalRatings': null,
  'locationLabel': location == null
      ? 'APPROXIMATE_SERVICE_AREA'
      : 'PUBLIC_SERVICE_LOCATION',
  'mapPoint': {'latitude': 6.93, 'longitude': 79.86},
  'distanceKm': .5,
  'remainingCapacity': 1,
  'languages': ['ENGLISH', 'SINHALA'],
};
Map<String, dynamic> requirementJson({
  int id = 1,
  String type = 'TEXT',
  Object? value,
  String status = 'MISSING',
}) => {
  'requirement': {
    'requirementId': id,
    'version': 1,
    'status': 'ACTIVE',
    'definition': {
      'code': 'REQUIREMENT_$id',
      'label': 'Requirement $id',
      'description': null,
      'fieldType': type,
      'required': true,
      'verificationMode': 'ADMIN_REVIEW',
      'blocksBooking': true,
      'choices': [],
      'minimumFiles': null,
      'maximumFiles': null,
      'maximumFileSizeMb': 10,
      'allowedFileTypes': [],
      'displayOrder': id,
    },
  },
  'submission': status == 'MISSING'
      ? null
      : {
          'submissionId': id + 100,
          'requirementId': id,
          'value': value,
          'status': status,
          'expiresOn': null,
          'rejectionReason': status == 'REJECTED'
              ? 'Please correct the evidence'
              : null,
        },
};
Map<String, dynamic> bookingJson({
  int id = 100,
  String method = 'CASH',
  String payment = 'PENDING',
}) => {
  'jobId': id,
  'serviceTypeId': 3,
  'optionId': 12,
  'providerId': 15,
  'providerIds': [15],
  'deliveryMode': 'PROVIDER_TO_CUSTOMER',
  'startDatetime': '2030-01-07T08:00:00',
  'expectedEndDatetime': '2030-01-07T10:00:00',
  'expectedAmount': 2400,
  'currencyCode': 'LKR',
  'paymentMethod': method,
  'status': 'PENDING',
  'paymentStatus': payment,
  'answers': {},
};

class BookingFixture extends DiscoveryFixture {
  bool autoAvailability = false;
  Duration availabilityDebounce = const Duration(milliseconds: 500);
  late CustomerBookingController journey;
  Map<String, dynamic> contextBody = contextJson();
  Map<String, dynamic> policyBody = {'enabled': false};
  int requestCreateStatus = 201;
  int walletConfirmationStatus = 200;
  Map<String, dynamic> requestViewBody = {
    'requestId': 501,
    'status': 'MATCHING',
    'paymentStatus': 'NOT_STARTED',
    'jobId': null,
    'expectedAmount': 1000,
    'currencyCode': 'LKR',
  };
  final Map<int, Map<String, dynamic>> optionContexts = {};
  List<Object?> requirementBody = [];
  Map<String, dynamic> eligibility = {'eligible': true, 'reasons': []};
  List<Map<String, dynamic>> candidateRows = [candidateJson()];
  List<Map<String, dynamic>> bookings = [];
  int searchStatus = 200,
      createStatus = 201,
      requirementStatus = 200,
      capStatus = 200,
      paymentStatus = 200;
  bool hasNext = false, throwBooking = false, hasSavedCard = true;
  int? candidateTotal;
  int quoteStatus = 200;
  int estimateStatus = 200;
  Map<String, dynamic> estimateBody = {
    'expectedAmount': 3000,
    'currencyCode': 'LKR',
  };
  Completer<void>? pendingQuote;
  Map<String, dynamic> quoteBody = {
    'expectedAmount': 2400,
    'currencyCode': 'LKR',
    'pricingSnapshot': null,
  };
  Map<String, Object?>? searchError;
  Completer<void>? pendingSearch, pendingBook;
  Map<String, dynamic> paymentOperation = {
    'intentId': 23,
    'purpose': 'CARD',
    'status': 'PENDING',
  };
  void install() {
    f.adapter.extraHandler = (request) async {
      final path = Uri.parse(request.path).path;
      Object? body;
      var status = 200;
      switch (path) {
        case '/customers/me/booking-requests/policy':
          body = policyBody;
        case '/customers/me/booking-requests':
          status = requestCreateStatus;
          body = status == 201
              ? {
                  ...requestViewBody,
                  'selectionMode':
                      contextBody['selection']['option']['providerSelectionMode'],
                }
              : {'detail': 'Request could not be confirmed'};
        case '/customers/me/booking-requests/501/confirm-wallet':
          status = walletConfirmationStatus;
          if (status == 200) {
            requestViewBody = {
              ...requestViewBody,
              'status': 'CONFIRMED',
              'paymentStatus': 'RESERVED',
              'jobId': 70,
              'paymentMethod': 'WALLET',
            };
            body = {
              ...requestViewBody,
              'selectionMode':
                  contextBody['selection']['option']['providerSelectionMode'],
            };
          } else {
            body = {'detail': 'Insufficient available wallet balance'};
          }
        case '/customers/me/booking-requests/501/cancel':
          requestViewBody = {...requestViewBody, 'status': 'CANCELLED'};
          body = {
            ...requestViewBody,
            'selectionMode':
                contextBody['selection']['option']['providerSelectionMode'],
          };
        case '/customers/me/booking-requests/501':
          body = {
            ...requestViewBody,
            'selectionMode':
                contextBody['selection']['option']['providerSelectionMode'],
          };
        case '/customers/me/booking-context':
          body =
              optionContexts[int.tryParse(
                request.uri.queryParameters['optionId'] ?? '',
              )] ??
              contextBody;
        case '/customers/me/requirements':
          body = requirementBody;
        case '/customers/me/eligibility':
          body = eligibility;
        case '/me/payment-methods':
          body = [
            if (hasSavedCard)
              {
                'methodId': 5,
                'type': 'CARD',
                'displayLabel': 'TEST CARD 4242',
                'status': 'VERIFIED_MOCK',
              },
          ];
        case '/me/wallets/LKR':
          body = {
            'walletId': 10,
            'currencyCode': 'LKR',
            'available': 1000,
            'reserved': 0,
            'pending': 0,
            'status': 'ACTIVE',
          };
        case '/me/wallets/LKR/transactions':
          body = {'number': 0, 'last': true, 'content': []};
        case '/me/wallets/LKR/reconciliation':
          body = {'walletId': 10, 'balanced': true};
        case '/me/payment-settings':
          status = capStatus;
          body = {
            'capabilities': {'cardCheckout': true, 'bookingReservations': true},
          };
        case '/customers/me/requirement-submissions':
          status = requirementStatus;
          body = [];
        case '/customers/me/provider-search':
          await pendingSearch?.future;
          status = searchStatus;
          body =
              searchError ??
              {
                'checkedAt': '2030-01-01T00:00:00Z',
                'marketId': 1,
                'timezone': 'Asia/Colombo',
                'startAt': '2030-01-07T08:00:00+05:30',
                'endAt': '2030-01-07T10:00:00+05:30',
                'providerSelectionMode':
                    (contextBody['selection']['option']
                        as Map)['providerSelectionMode'],
                'requiredProviderCount':
                    (contextBody['selection']['option']
                        as Map)['requiredProviderCount'],
                'status': candidateRows.isEmpty
                    ? 'NO_AVAILABLE_PROVIDERS'
                    : 'AVAILABLE',
                'totalCandidates': candidateTotal ?? candidateRows.length,
                'page': (request.data as Map)['page'],
                'pageSize': 20,
                'hasNext': hasNext,
                'candidates': candidateRows,
              };
        case '/customers/me/bookings/estimate':
          status = estimateStatus;
          body = estimateBody;
        case '/customers/me/bookings/quote':
          final snapshot = Map<String, dynamic>.from(quoteBody);
          await pendingQuote?.future;
          status = quoteStatus;
          body = snapshot;
        case '/customers/me/bookings':
          if (request.method == 'GET') {
            body = bookings;
          } else {
            await pendingBook?.future;
            if (throwBooking) {
              throw const NetworkException(
                kind: NetworkExceptionKind.timeout,
                message: 'Timed out',
              );
            }
            status = createStatus;
            body = createStatus == 201
                ? bookingJson(
                    method: (request.data as Map)['paymentMethod'] as String,
                  )
                : {
                    'detail': 'Availability changed',
                    'errors': {'providerIds': 'Search again'},
                  };
            if (createStatus == 201) bookings = [body as Map<String, dynamic>];
          }
        case '/customers/me/bookings/100/card-payment-session':
          status = paymentStatus;
          body = paymentOperation;
        case '/customers/me/bookings/100/wallet-payment':
          status = paymentStatus;
          body = {
            'operationId': 42,
            'jobId': 100,
            'type': 'BOOKING_RESERVE',
            'status': 'POSTED',
          };
          if (status == 200) {
            bookings = [bookingJson(method: 'WALLET', payment: 'RESERVED')];
          }
        case '/me/mock-payments/23/events':
          final outcome = (request.data as Map)['outcome'];
          final state = outcome == 'SUCCESS'
              ? 'SUCCEEDED'
              : outcome == 'REFUND'
              ? 'REFUNDED'
              : 'FAILED';
          body = {'intentId': 23, 'purpose': 'CARD', 'status': state};
          bookings = [
            bookingJson(
              method: 'CARD',
              payment: outcome == 'SUCCESS' ? 'PAID' : state,
            ),
          ];
        case '/uploads/documents':
          body = {
            'key': 'customers/12/documents/file.pdf',
            'contentType': 'application/pdf',
            'size': 5,
          };
        case '/uploads/view-url':
          body = {
            'url': 'https://example.invalid/private-view',
            'expiresAt': '2030-01-01T00:10:00Z',
          };
        default:
          return null;
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    };
  }

  @override
  Future<void> start() async {
    install();
    await super.start();
    await discovery.continueMarket();
    await waitForState(
      discovery,
      () => discovery.serviceStage == DiscoveryStage.ready,
    );
    journey = CustomerBookingController(
      const BookingKey(1, 3, 12),
      CustomerBookingRepository(f.service),
      f.controller,
      discovery,
      now: () => clock,
      autoAvailability: autoAvailability,
      availabilityDebounce: availabilityDebounce,
    );
    await journey.load();
  }

  void input() {
    journey.start = '2030-01-07T08:00:00';
    journey.end = '2030-01-07T10:00:00';
    journey.point = const GeoPoint(6.9271, 79.8612);
    journey.address = 'Test service address';
    journey.method = 'CASH';
  }

  Future<void> enterServiceDetails() async {
    await journey.nextServiceDetails();
    if (journey.stage == BookingStage.results) {
      for (final candidate in journey.candidates) {
        if (!journey.selected.containsKey(candidate.id)) {
          journey.select(candidate);
        }
        if (journey.selected.length == journey.context!.providerCount) break;
      }
      journey.continueWithProviders();
    }
  }

  @override
  void dispose() {
    journey.dispose();
    super.dispose();
  }
}
