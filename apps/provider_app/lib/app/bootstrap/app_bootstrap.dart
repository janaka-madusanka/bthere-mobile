import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../config/app_config.dart';
import '../providers/app_providers.dart';

/// Configuration is loaded before plugin/network dependencies are constructed.
AppConfig? loadAppConfig({bool nativeGoogleMapsConfigured = false}) {
  try {
    return AppConfig.fromEnvironment(
      nativeGoogleMapsConfigured: nativeGoogleMapsConfigured,
    );
  } on FormatException {
    return null;
  }
}

final class AppBootstrap extends StatelessWidget {
  const AppBootstrap({required this.config, super.key});
  final AppConfig? config;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [appConfigProvider.overrideWithValue(config)],
    child: const BThereProviderApp(),
  );
}
