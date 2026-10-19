import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/config/native_maps_configuration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bthere.provider/maps-configuration');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'native manifest configuration enables maps without a Dart key',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isConfigured');
            expect(call.arguments, isNull);
            return true;
          });
      final config = AppConfig(
        apiBaseUrl: 'https://example.invalid/api/v1',
        nativeGoogleMapsConfigured: await nativeMapsConfigured(),
      );
      expect(config.googleMapsApiKey, isEmpty);
      expect(config.hasGoogleMapsKey, isTrue);
    },
  );

  test(
    'missing native channel retains the normal configured-key behavior',
    () async {
      expect(await nativeMapsConfigured(), isFalse);
      expect(
        AppConfig(
          apiBaseUrl: 'https://example.invalid/api/v1',
          googleMapsApiKey: 'sample',
        ).hasGoogleMapsKey,
        isTrue,
      );
      expect(
        AppConfig(
          apiBaseUrl: 'https://example.invalid/api/v1',
          googleMapsApiKey: 'YOUR_GOOGLE_MAPS_API_KEY',
        ).hasGoogleMapsKey,
        isFalse,
      );
    },
  );
}
