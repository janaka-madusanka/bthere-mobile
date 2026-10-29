import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:customer_app/features/profile/presentation/customer_profile_photo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final photoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
);

class PhotoHttpClient implements HttpClient {
  int status = 403, calls = 0;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    calls++;
    return PhotoRequest(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PhotoRequest implements HttpClientRequest {
  PhotoRequest(this.client);
  final PhotoHttpClient client;
  @override
  Future<HttpClientResponse> close() async => PhotoResponse(client.status);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  PhotoResponse(this.statusCode);
  @override
  final int statusCode;
  @override
  int get contentLength => statusCode == 200 ? photoBytes.length : 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable(statusCode == 200 ? [photoBytes] : [])
      .listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settleImage(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  late PhotoHttpClient client;
  setUp(() {
    client = PhotoHttpClient();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugNetworkImageHttpClientProvider = () => client;
  });
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
  });
  testWidgets(
    'failed server image shows no local fallback and logs only status',
    (tester) async {
      final priorDebugPrint = debugPrint;
      try {
        final messages = <String>[];
        final previousPrint = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) messages.add(message);
        };
        addTearDown(() => debugPrint = previousPrint);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomerProfilePhoto(
                url: 'https://example.invalid/private-object-path?signature=secret',
                uploading: false,
                enabled: true,
                onPick: () {},
                onRemove: () {},
              ),
            ),
          ),
        );
        await settleImage(tester);
        expect(
          find.byKey(const ValueKey('customer-profile-photo-local-preview')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('customer-profile-photo-load-error')),
          findsOneWidget,
        );
        expect(messages.join(), contains('status=403'));
        expect(messages.join(), isNot(contains('private-object-path')));
        expect(messages.join(), isNot(contains('signature')));
        expect(messages.join(), isNot(contains('secret')));
        expect(tester.takeException(), isNull);
        client.status = 200;
        await tester.tap(
          find.byKey(const ValueKey('customer-profile-photo-retry')),
        );
        await settleImage(tester);
        expect(client.calls, 2);
        expect(
          tester.widget<Image>(find.byType(Image)).image,
          isA<NetworkImage>(),
        );
        expect(find.byType(RawImage), findsOneWidget);
        expect(
          find.byKey(const ValueKey('customer-profile-photo-load-error')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('customer-profile-photo-local-preview')),
          findsNothing,
        );
      } finally {
        debugPrint = priorDebugPrint;
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
  testWidgets(
    'failed server URL shows readable failure instead of silent placeholder',
    (tester) async {
      final priorDebugPrint = debugPrint;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomerProfilePhoto(
                url: 'https://example.invalid/saved.jpg',
                uploading: false,
                enabled: true,
                onPick: () {},
                onRemove: () {},
              ),
            ),
          ),
        );
        await settleImage(tester);
        expect(
          find.text(
            'The server photo could not be displayed. Retry loading it or choose another photo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Retry photo'), findsOneWidget);
      } finally {
        debugPrint = priorDebugPrint;
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
  testWidgets(
    'remove clears photo and changing server URL replaces prior failure state',
    (tester) async {
      final priorDebugPrint = debugPrint;
      try {
        String? url = 'https://example.invalid/first.jpg';
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return CustomerProfilePhoto(
                    url: url,
                    uploading: false,
                    enabled: true,
                    onPick: () {},
                    onRemove: () => setState(() {
                      url = null;
                    }),
                  );
                },
              ),
            ),
          ),
        );
        await settleImage(tester);
        await tester.tap(find.text('Remove photo'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('customer-profile-photo-local-preview')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('customer-profile-photo-load-error')),
          findsNothing,
        );
        expect(find.text('Add a profile photo (optional)'), findsOneWidget);
        client.status = 200;
        update(() {
          url = 'https://example.invalid/second.jpg';
        });
        await settleImage(tester);
        expect(
          find.byKey(const ValueKey('customer-profile-photo-load-error')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugPrint = priorDebugPrint;
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
}
