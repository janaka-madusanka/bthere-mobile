import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'app/customer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustomerBootstrap());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Move the SDK's one-time native initialization away from entering the
    // booking screen. This does not request permission or read GPS location.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        const String.fromEnvironment('BTHERE_GOOGLE_MAPS_API_KEY').isNotEmpty) {
      final maps = GoogleMapsFlutterPlatform.instance;
      if (maps is GoogleMapsFlutterAndroid) maps.warmup().ignore();
    }
  });
}
