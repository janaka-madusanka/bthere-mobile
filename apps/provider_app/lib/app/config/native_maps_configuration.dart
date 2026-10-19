import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns the Maps SDK key; query availability without exposing its value.
Future<bool> nativeMapsConfigured() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    return await const MethodChannel('com.bthere.provider/maps-configuration')
            .invokeMethod<bool>('isConfigured') ==
        true;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
