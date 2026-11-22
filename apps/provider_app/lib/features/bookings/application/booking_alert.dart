import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns a looping system ringtone; other platforms use a system alert.
class BookingAlert {
  static const _channel = MethodChannel('com.bthere.provider/booking-alert');
  static Future<void> start() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod<void>('start');
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } on MissingPluginException {
      await SystemSound.play(SystemSoundType.alert);
    } on PlatformException {
      // Visual controls and countdown stay available when audio is unavailable.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No looping alert on this platform.
    } on PlatformException {
      // Native activity teardown also stops its ringtone.
    }
  }
}
