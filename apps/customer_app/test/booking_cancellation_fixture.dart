import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';

import 'booking_fixture.dart';

Map<String, dynamic> cancellationJson({
  bool receipt = false,
  String by = 'CUSTOMER',
}) => {
  'jobId': 70,
  'cancelledBy': by,
  'currencyCode': 'LKR',
  'paidAmount': 10000.00,
  'refundAmount': 4800.00,
  'refundPercentage': 50.00,
  'cancellationFee': 200.00,
  'retainedAmount': 5200.00,
  'providerAmount': 3640.00,
  'platformAmount': 1560.00,
  'refundDestination': 'WALLET',
  'refundTierName': 'Two hours',
  'refundPolicyId': 3,
  'refundPolicyVersion': 2,
  if (receipt) ...{
    'cancellationId': 12,
    'requestId': 501,
    'paymentStatus': 'PARTIALLY_REFUNDED',
    'reason': 'Plans changed',
    'walletOperationId': 88,
  },
};

class CancellationBackend {
  Map<String, dynamic> preview = cancellationJson();
  Map<String, dynamic>? saved;
  int postStatus = 200, writes = 0;
  bool timeout = false;
  int? receiptStatus;
  Completer<void>? gate, started;
  void install(BookingFixture f) {
    final previous = f.f.adapter.extraHandler!;
    f.f.adapter.extraHandler = (r) async {
      if (r.path.endsWith('/bookings/70/cancellation-preview')) {
        return response(preview, 200);
      }
      if (r.path.endsWith('/bookings/70/cancel')) {
        writes++;
        if (gate != null) {
          started?.complete();
          await gate!.future;
        }
        if (timeout) {
          throw const NetworkException(
            kind: NetworkExceptionKind.timeout,
            message: 'Timeout',
          );
        }
        if (postStatus != 200) {
          return response({
            'detail': 'The refund amount changed; review it and try again',
          }, postStatus);
        }
        saved = {
          ...cancellationJson(receipt: true),
          'refundAmount': preview['refundAmount'],
        };
        f.bookings = [
          {
            ...f.bookings.single,
            'status': 'CANCELLED',
            'paymentStatus': 'PARTIALLY_REFUNDED',
          },
        ];
        return response(saved!, 200);
      }
      if (r.path.endsWith('/bookings/70/cancellation')) {
        return response(
          saved ?? {'detail': 'No cancellation'},
          receiptStatus ?? (saved == null ? 404 : 200),
        );
      }
      return previous(r);
    };
  }

  ResponseBody response(Object value, int status) => ResponseBody.fromString(
    jsonEncode(value),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}
