import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Load only Home's bundled families; other screens retain their test fonts.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in {
    'HomeInter': ['Inter.ttf'],
    'HomeLato': ['Lato-Regular.ttf', 'Lato-Bold.ttf', 'Lato-Black.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }
  await testMain();
}
