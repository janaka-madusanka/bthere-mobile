import 'dart:convert';
import 'dart:typed_data';

/// Server-signed hosted checkout. Card credentials never pass through the app API.
class BookingCardCheckout {
  BookingCardCheckout._(this.action, this.fields);
  final Uri action;
  final Map<String, String> fields;

  factory BookingCardCheckout.parse(Object? value) {
    if (value is! Map ||
        value['status'] != 'PAYMENT_PENDING' ||
        value['fields'] is! Map) {
      throw const FormatException('Invalid card checkout');
    }
    final action = Uri.tryParse('${value['actionUrl']}');
    if (action == null ||
        action.scheme != 'https' ||
        action.userInfo.isNotEmpty ||
        !{
          'sandbox.payhere.lk',
          'www.payhere.lk',
          'payhere.lk',
        }.contains(action.host) ||
        action.port != 443 ||
        action.path != '/pay/checkout' ||
        action.hasFragment) {
      throw const FormatException('Invalid checkout destination');
    }
    final raw = value['fields'] as Map;
    if (raw.entries.any((e) => e.key is! String || e.value is! String)) {
      throw const FormatException('Invalid checkout fields');
    }
    final fields = Map<String, String>.from(raw);
    for (final key in [
      'merchant_id',
      'order_id',
      'amount',
      'currency',
      'hash',
      'return_url',
      'cancel_url',
    ]) {
      if (fields[key]?.trim().isNotEmpty != true) {
        throw const FormatException('Incomplete checkout');
      }
    }
    for (final key in ['return_url', 'cancel_url']) {
      final uri = Uri.tryParse(fields[key]!);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid checkout callback');
      }
    }
    return BookingCardCheckout._(action, Map.unmodifiable(fields));
  }

  Uint8List get body =>
      Uint8List.fromList(utf8.encode(Uri(queryParameters: fields).query));

  bool isReturn(Uri uri) =>
      uri.scheme == 'https' &&
      uri.hasAuthority &&
      ['return_url', 'cancel_url'].any((key) {
        final expected = Uri.parse(fields[key]!);
        return uri.origin == expected.origin &&
            uri.path == expected.path &&
            expected.queryParameters.entries.every(
              (e) => uri.queryParameters[e.key] == e.value,
            );
      });
}
