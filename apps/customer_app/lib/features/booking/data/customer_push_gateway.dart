import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class BookingPush {
  const BookingPush(this.data, {this.opened = false});
  final Map<String, dynamic> data;
  final bool opened;
}

abstract class CustomerPushGateway {
  Future<bool> initialize();
  Future<String?> token({bool askPermission = false});
  Stream<String> get tokens;
  Stream<BookingPush> get messages;
  Future<BookingPush?> initialMessage();
  Future<void> deleteToken();
}

final customerPushGatewayProvider = Provider<CustomerPushGateway>((ref) {
  final gateway = FirebaseCustomerPush();
  ref.onDispose(gateway.dispose);
  return gateway;
});

@pragma('vm:entry-point')
Future<void> customerBackgroundMessage(RemoteMessage message) async {
  // OS displays notification payload; never perform account/payment writes here.
  await Firebase.initializeApp();
}

class FirebaseCustomerPush implements CustomerPushGateway {
  final _messages = StreamController<BookingPush>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> subscriptions = [];
  bool ready = false, disposed = false;
  Future<bool>? initializing;
  @override
  Future<bool> initialize() =>
      initializing ??= _initialize().whenComplete(() => initializing = null);
  Future<bool> _initialize() async {
    if (ready) return true;
    if (disposed ||
        kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return false;
    }
    try {
      await Firebase.initializeApp();
      if (disposed) return false;
      FirebaseMessaging.onBackgroundMessage(customerBackgroundMessage);
      subscriptions.add(
        FirebaseMessaging.onMessage.listen(
          (m) => _messages.add(BookingPush(m.data)),
        ),
      );
      subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (m) => _messages.add(BookingPush(m.data, opened: true)),
        ),
      );
      subscriptions.add(
        // Backend currently accepts FCM registration tokens, not FIDs.
        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen(
          _tokens.add,
          onError: (_) {},
        ),
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token({bool askPermission = false}) async {
    if (!ready) return null;
    final settings = askPermission
        ? await FirebaseMessaging.instance.requestPermission()
        : await FirebaseMessaging.instance.getNotificationSettings();
    if (![
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(settings.authorizationStatus)) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      return null;
    }
    // Backend booking-devices contract explicitly requires a registration token.
    // ignore: deprecated_member_use
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get tokens => _tokens.stream;
  @override
  Stream<BookingPush> get messages => _messages.stream;
  @override
  Future<BookingPush?> initialMessage() async {
    if (!ready) return null;
    final value = await FirebaseMessaging.instance.getInitialMessage();
    return value == null ? null : BookingPush(value.data, opened: true);
  }

  @override
  Future<void> deleteToken() async {
    if (ready) {
      // Revoke the same legacy token accepted by the current backend contract.
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    }
  }

  void dispose() {
    disposed = true;
    for (final sub in subscriptions) {
      sub.cancel();
    }
    _tokens.close();
    _messages.close();
  }
}
