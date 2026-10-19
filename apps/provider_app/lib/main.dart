import 'package:flutter/widgets.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/config/native_maps_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mapsConfigured = await nativeMapsConfigured();
  runApp(
    AppBootstrap(
      config: loadAppConfig(nativeGoogleMapsConfigured: mapsConfigured),
    ),
  );
}
