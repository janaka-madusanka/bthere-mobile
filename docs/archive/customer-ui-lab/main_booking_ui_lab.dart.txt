import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'debug/booking_ui_lab.dart';

class _NoLabNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) => Future.error(
      const SocketException('Booking UI lab blocks network connections'),
    );
    return client;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !const bool.fromEnvironment('BTHERE_BOOKING_UI_LAB')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Booking UI lab requires its debug launch script.'),
          ),
        ),
      ),
    );
    return;
  }
  HttpOverrides.global = _NoLabNetwork();
  tz.initializeTimeZones();
  runApp(
    BookingUiLab(
      initialScene: BookingLabScene.parse(
        const String.fromEnvironment(
          'BTHERE_BOOKING_UI_LAB_SCENE',
          defaultValue: 'ready',
        ),
      ),
    ),
  );
}
