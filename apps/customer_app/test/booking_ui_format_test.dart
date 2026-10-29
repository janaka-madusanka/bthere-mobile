import 'package:customer_app/features/booking/presentation/booking_ui_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'location labels show a named place rather than GPS codes or house numbers',
    () {
      const cases = {
        '7P9X+5M, Kurunegala, Sri Lanka': 'Kurunegala',
        '7P9X+5M Kurunegala, Sri Lanka': 'Kurunegala',
        '123/4, Main Street, Kurunegala': 'Main Street',
        'No. 123/4 Main Street, Kurunegala': 'Main Street',
        'Unnamed Road, Mawanella, Sri Lanka': 'Mawanella',
        'A6, Kurunegala, Sri Lanka': 'Kurunegala',
        '7.48, 80.36': 'Selected on map',
        '123/4, කුරුණෑගල, ශ්‍රී ලංකාව': 'කුරුණෑගල',
        '2nd Lane, Colombo': '2nd Lane',
      };
      for (final entry in cases.entries) {
        expect(bookingShortAddress(entry.key), entry.value, reason: entry.key);
      }
    },
  );
}
