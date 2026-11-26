import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';

enum BookingLabScene {
  ready('ready', 'Ready · 4 hr 23 min'),
  readyCode('ready-code', 'Ready · 23 min / start code'),
  inProgress('in-progress', 'Service in progress'),
  completion('confirm-completion', 'Confirm completion'),
  completed('completed', 'Completed · add review'),
  reviewed('reviewed', 'Completed · saved review'),
  paymentFailed('payment-failed', 'Payment failed · retry available'),
  paymentExpired('payment-expired', 'Payment deadline expired'),
  cancelled('cancelled', 'Cancelled · wallet refund'),
  loading('loading', 'Loading skeleton'),
  error('error', 'API error / retry');

  const BookingLabScene(this.id, this.label);
  final String id, label;
  static BookingLabScene parse(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => ready);
}

class LabSessionStorage implements SessionStorage {
  LabSessionStorage(this.value);
  AuthSession? value;
  @override
  Future<AuthSession?> read() async => value;
  @override
  Future<void> write(AuthSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class LabKeyValueStore implements SecureKeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// No network fallback. Unknown paths return a local 501, including writes.
/// Fixtures use the documented API shapes; real repositories parse them.
class BookingLabBackend implements HttpClientAdapter {
  BookingLabBackend(this.scene) {
    final start = base.add(
      scene == BookingLabScene.readyCode
          ? const Duration(minutes: 23)
          : const Duration(hours: 4, minutes: 23),
    );
    final status = switch (scene) {
      BookingLabScene.inProgress => 'IN_PROGRESS',
      BookingLabScene.completion => 'AWAITING_COMPLETION_CONFIRMATION',
      BookingLabScene.completed || BookingLabScene.reviewed => 'COMPLETED',
      BookingLabScene.paymentFailed => 'AWAITING_PAYMENT',
      BookingLabScene.paymentExpired ||
      BookingLabScene.cancelled => 'CANCELLED',
      _ => 'CONFIRMED',
    };
    booking = {
      'jobId': jobId, 'requestId': requestId, 'marketId': 1,
      'marketTimezone': 'Asia/Colombo', 'serviceTypeId': 1,
      'optionName': 'Hospital Care', 'optionId': 1,
      'providerId': 15,
      'providerIds': [15],
      'deliveryMode': 'PROVIDER_TO_CUSTOMER',
      'schedulingModel': 'TIME_BASED', 'status': status,
      'actualStartedAt':
          {
            'IN_PROGRESS',
            'AWAITING_COMPLETION_CONFIRMATION',
            'COMPLETED',
          }.contains(status)
          ? base
                .subtract(const Duration(hours: 1, minutes: 23))
                .toIso8601String()
          : null,
      'actualFinishedAt':
          {'AWAITING_COMPLETION_CONFIRMATION', 'COMPLETED'}.contains(status)
          ? base.subtract(const Duration(minutes: 3)).toIso8601String()
          : null,
      'completionConfirmedAt': status == 'COMPLETED'
          ? base.toIso8601String()
          : null,
      'paymentMethod': 'WALLET',
      'paymentStatus': status == 'COMPLETED'
          ? 'SETTLED'
          : scene == BookingLabScene.cancelled
          ? 'REFUNDED'
          : scene == BookingLabScene.paymentFailed
          ? 'FAILED'
          : scene == BookingLabScene.paymentExpired
          ? 'NOT_STARTED'
          : 'RESERVED',
      'expectedAmount': 21000, 'currencyCode': 'LKR',
      // API time-based bookings use market-local wall times, not device time.
      'startDatetime': start
          .add(const Duration(hours: 5, minutes: 30))
          .toIso8601String()
          .replaceFirst('Z', ''),
      'expectedEndDatetime': start
          .add(const Duration(hours: 11, minutes: 30))
          .toIso8601String()
          .replaceFirst('Z', ''),
      'meetingPointName': 'Hospital Road, Colombo 10',
      'latitude': 6.9271, 'longitude': 79.8612,
      'answers': {
        'CG_PATIENT_NAME': 'Sample patient',
        'CG_CONTACT_NUMBER': 'Not a real contact',
        'CG_HOSPITAL_NAME': 'Sample hospital',
        'CG_WARD_NUMBER': 'A3',
        'CG_BED_NUMBER': '12',
        'CG_ADDITIONAL_INFORMATION': 'Assistance with mobility requested.',
      },
    };
    rated = scene == BookingLabScene.reviewed;
  }
  static const jobId = 7001, requestId = 9001;
  final BookingLabScene scene;
  final base = DateTime.utc(2026, 11, 19, 10);
  final elapsed = Stopwatch()..start();
  DateTime get now => base.add(elapsed.elapsed);
  late Map<String, dynamic> booking;
  bool rated = false, disposed = false;
  int stars = 4;
  String comment = 'Very professional and caring service.';
  final calls = <String>[];
  final loading = Completer<void>();
  final messages = <Map<String, dynamic>>[];
  int readId = 0;

  Map<String, dynamic> get request => {
    'requestId': requestId,
    'jobId': jobId,
    'userId': 12,
    'providerId': 15,
    'selectionMode': 'OPEN_REQUEST',
    'expectedAmount': 21000,
    'currencyCode': 'LKR',
    'paymentMethod': booking['paymentMethod'],
    'paymentStatus': booking['paymentStatus'],
    'status': scene == BookingLabScene.paymentExpired
        ? 'EXPIRED'
        : booking['status'] == 'AWAITING_PAYMENT'
        ? 'AWAITING_CUSTOMER_CONFIRMATION'
        : booking['status'],
    'confirmationExpiresAt': base
        .add(const Duration(minutes: 45))
        .toIso8601String(),
    'paymentRetryStartedAt': scene == BookingLabScene.paymentFailed
        ? base.toIso8601String()
        : null,
  };
  Map<String, dynamic> get provider => {
    'providerId': 15,
    'role': 'PRIMARY',
    'displayName': 'Nimal Perera',
    'profilePhoto': null,
    'averageRating': 4.8,
    'totalRatings': 23,
    'ratedByYou': rated,
    'contact': {
      'callAllowed': {'CONFIRMED', 'IN_PROGRESS'}.contains(booking['status']),
      'phoneNumber': '0000000000',
      'unavailableReason': 'BOOKING_ENDED',
    },
  };
  Map<String, dynamic> cancellation({bool receipt = false}) => {
    'jobId': jobId,
    'requestId': requestId,
    'cancelledBy': 'CUSTOMER',
    'refundDestination': 'WALLET',
    'paidAmount': 21000,
    'refundAmount': 21000,
    'cancellationFee': 0,
    'retainedAmount': 0,
    'providerAmount': 0,
    'platformAmount': 0,
    'currencyCode': 'LKR',
    'refundTierName': 'Before service start',
    'reason': 'Plans changed',
    'note': null,
    if (receipt) ...{'cancellationId': 4001, 'paymentStatus': 'REFUNDED'},
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.uri.host != 'booking-ui-lab.invalid') {
      throw StateError('UI lab cannot access a real API host');
    }
    final path = options.uri.path.replaceFirst('/api/v1', '');
    calls.add('${options.method} $path');
    Object? body;
    var status = 200;
    final data = options.data is Map ? options.data as Map : const {};
    switch (path) {
      case '/customers/me/bookings':
        if (scene == BookingLabScene.loading) await loading.future;
        status = scene == BookingLabScene.error || disposed ? 503 : 200;
        body = status == 200 ? [booking] : {'detail': 'Sample API error'};
      case '/customers/me/bookings/$jobId/providers':
        body = {
          'jobId': jobId,
          'providers': [provider],
        };
      case '/customers/me/bookings/$jobId/verification-codes':
        body = {
          'purpose': 'START',
          'code': '0472',
          'expiresAt': base.add(const Duration(days: 1)).toIso8601String(),
        };
      case '/customers/me/bookings/$jobId/tracking':
        body = {
          'jobId': jobId,
          'jobStatus': booking['status'],
          'status': 'NOT_STARTED',
          'mode': 'JOURNEY_TO_SERVICE',
          'pollIntervalSeconds': 15,
          'target': {
            'latitude': 6.9271,
            'longitude': 79.8612,
            'label': 'Service location',
          },
          'providers': [],
        };
      case '/customers/me/bookings/$jobId/ratings':
        if (options.method == 'POST') {
          rated = true;
          stars = data['rating'] as int;
          comment = data['comment'] as String? ?? '';
          status = 201;
          body = {
            'jobId': jobId,
            'providerId': 15,
            'rating': stars,
            'comment': comment,
          };
        } else {
          body = {
            'jobId': jobId,
            'jobStatus': booking['status'],
            'canRate': !rated,
            'providers': [
              {
                ...provider,
                'rated': rated,
                'rating': rated ? {'rating': stars, 'comment': comment} : null,
              },
            ],
          };
        }
      case '/customers/me/bookings/$jobId/confirm-completion':
        booking = {
          ...booking,
          'status': 'COMPLETED',
          'paymentStatus': 'SETTLED',
        };
        body = {'successful': true, 'status': 'COMPLETED'};
      case '/customers/me/bookings/$jobId/cancellation-preview':
        body = cancellation();
      case '/customers/me/bookings/$jobId/cancel':
        booking = {
          ...booking,
          'status': 'CANCELLED',
          'paymentStatus': 'REFUNDED',
        };
        body = {
          ...cancellation(receipt: true),
          'reason': data['reason'],
          'note': data['note'],
        };
      case '/customers/me/bookings/$jobId/cancellation':
        if (booking['paymentStatus'] == 'REFUNDED') {
          body = cancellation(receipt: true);
        } else {
          status = 404;
          body = {'detail': 'No sample cancellation'};
        }
      case '/customers/me/booking-requests/$requestId':
        body = request;
      case '/customers/me/booking-requests/$requestId/payment-window':
        body = {
          ...request,
          'canPay': booking['status'] == 'AWAITING_PAYMENT',
          'canCancel': booking['status'] == 'AWAITING_PAYMENT',
        };
      case '/customers/me/booking-events':
        body = [
          {
            'eventId': 1,
            'requestId': requestId,
            'userId': 12,
            'eventType': 'PROVIDER_ACCEPTED',
          },
        ];
      case '/customers/me/conversations':
        body = {
          'conversations': [
            {
              'jobId': jobId,
              'jobStatus': booking['status'],
              'canSend': true,
              'participants': [
                {...provider, 'you': false},
              ],
              'lastMessage': null,
              'unreadCount': 0,
            },
          ],
          'totalUnread': 0,
        };
      case '/customers/me/bookings/$jobId/messages':
        if (options.method == 'POST') {
          final id = data['clientMessageId'];
          body = messages.where((m) => m['clientMessageId'] == id).firstOrNull;
          if (body == null) {
            body = {
              'messageId': messages.length + 1,
              'senderRole': 'CUSTOMER',
              'senderName': 'Sample customer',
              'fromYou': true,
              'text': data['text'],
              'contactInfoHidden': false,
              'sentAt': now.toIso8601String(),
              'clientMessageId': id,
            };
            messages.add(Map<String, dynamic>.from(body as Map));
          }
          status = 201;
        } else {
          final after =
              int.tryParse(options.uri.queryParameters['after'] ?? '') ?? 0;
          body = {
            'jobId': jobId,
            'jobStatus': booking['status'],
            'canSend': true,
            'sendUntil': null,
            'participants': [
              {...provider, 'you': false},
            ],
            'messages': messages
                .where((m) => (m['messageId'] as int) > after)
                .toList(),
            'hasOlder': false,
            'hasNewer': false,
            'yourLastReadMessageId': readId,
            'othersLastReadMessageId': 0,
            'unreadCount': 0,
          };
        }
      case '/customers/me/bookings/$jobId/messages/read':
        readId = data['lastReadMessageId'] as int;
        body = {
          'jobId': jobId,
          'yourLastReadMessageId': readId,
          'unreadCount': 0,
        };
      default:
        status = 501;
        body = {'detail': 'This action is not part of the current UI review.'};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    disposed = true;
    elapsed.stop();
    if (!loading.isCompleted) loading.complete();
  }
}
