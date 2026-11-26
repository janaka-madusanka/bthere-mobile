import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native notifications only contain owned request references, never credentials.
abstract class ActiveRequestNotifications {
  Stream<Map<String, dynamic>> get opens;
  Future<Map<String, dynamic>?> initialOpen();
  Future<void> show(Map<String, dynamic> data);
  Future<void> clear();
}

final activeRequestNotificationsProvider = Provider<ActiveRequestNotifications>(
  (ref) {
    final gateway = AndroidActiveRequestNotifications();
    ref.onDispose(gateway.dispose);
    return gateway;
  },
);

class AndroidActiveRequestNotifications implements ActiveRequestNotifications {
  static const channel = MethodChannel('com.bthere.customer/active-request');
  final _opens = StreamController<Map<String, dynamic>>.broadcast();
  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AndroidActiveRequestNotifications() {
    if (available) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'open' &&
            call.arguments is Map &&
            !_opens.isClosed) {
          _opens.add(Map<String, dynamic>.from(call.arguments as Map));
        }
      });
    }
  }
  @override
  Stream<Map<String, dynamic>> get opens => _opens.stream;
  @override
  Future<Map<String, dynamic>?> initialOpen() async {
    if (!available) return null;
    try {
      return await channel.invokeMapMethod<String, dynamic>('initialOpen');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> show(Map<String, dynamic> data) async {
    if (!available) return;
    try {
      await channel.invokeMethod<void>('show', data);
    } on MissingPluginException {
      /* Non-native/widget test host. */
    } on PlatformException {
      /* Permission/OS restrictions do not block booking. */
    }
  }

  @override
  Future<void> clear() async {
    if (!available) return;
    try {
      await channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // No native host in widget tests.
    } on PlatformException {
      // Clearing an unavailable OS notification is harmless.
    }
  }

  void dispose() {
    if (available) channel.setMethodCallHandler(null);
    _opens.close();
  }
}
