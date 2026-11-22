import 'dart:async';
import 'dart:convert';

import 'package:customer_app/features/discovery/data/customer_catalog_media_cache.dart';
import 'package:customer_app/features/discovery/presentation/customer_discovery_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'concurrent URL requests and later navigation share one download',
    () async {
      var calls = 0;
      final gate = Completer<void>();
      final cache = CatalogMediaCache(
        client: MockClient((r) async {
          calls++;
          await gate.future;
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      addTearDown(cache.dispose);
      final first = cache.load('https://example.invalid/icon.png');
      final second = cache.load('https://example.invalid/icon.png');
      gate.complete();
      expect(identical(await first, await second), isTrue);
      await cache.load('https://example.invalid/icon.png');
      expect(calls, 1);
    },
  );
  test('expiry uses conditional revalidation, retaining the same image bytes on 304', () async {
    var now = DateTime.utc(2030);
    var calls = 0;
    final cache = CatalogMediaCache(
      now: () => now,
      client: MockClient((r) async {
        calls++;
        if (calls == 2) {
          expect(r.headers['if-none-match'], 'v1');
          return http.Response(
            '',
            304,
            headers: {'cache-control': 'max-age=60'},
          );
        }
        return http.Response.bytes(
          [1, 2],
          200,
          headers: {
            'etag': 'v1',
            'cache-control': 'max-age=60',
            'content-type': 'image/svg+xml',
          },
        );
      }),
    );
    addTearDown(cache.dispose);
    final first = await cache.load('https://example.invalid/icon');
    now = now.add(const Duration(seconds: 61));
    expect(cache.peek('https://example.invalid/icon'), same(first));
    final refreshed = await cache.load('https://example.invalid/icon');
    expect(refreshed.bytes, same(first.bytes));
    expect(refreshed.svg, isTrue);
    expect(cache.fresh(refreshed), isTrue);
    expect(calls, 2);
  });
  test('LRU is bounded and distinct versioned URLs load immediately', () async {
    var calls = 0;
    final cache = CatalogMediaCache(
      maximumEntries: 2,
      maximumBytes: 4,
      client: MockClient((r) async {
        calls++;
        return http.Response.bytes([1, 2], 200);
      }),
    );
    addTearDown(cache.dispose);
    for (final version in [1, 2, 3]) {
      await cache.load('https://example.invalid/icon.png?v=$version');
    }
    expect(cache.peek('https://example.invalid/icon.png?v=1'), isNull);
    expect(cache.peek('https://example.invalid/icon.png?v=3'), isNotNull);
    expect(calls, 3);
  });
  test(
    'no-store is honored and oversized responses are not retained',
    () async {
      var calls = 0;
      final cache = CatalogMediaCache(
        maximumFileBytes: 4,
        client: MockClient((r) async {
          calls++;
          return http.Response.bytes(
            List.filled(r.url.path.contains('big') ? 5 : 2, 1),
            200,
            headers: {'cache-control': 'no-store'},
          );
        }),
      );
      addTearDown(cache.dispose);
      await cache.load('https://example.invalid/icon.png');
      await cache.load('https://example.invalid/icon.png');
      expect(calls, 2);
      expect(cache.peek('https://example.invalid/icon.png'), isNull);
      await expectLater(
        cache.load('https://example.invalid/big.png'),
        throwsStateError,
      );
      expect(cache.peek('https://example.invalid/big.png'), isNull);
    },
  );
  test('failed images have a short retry cooldown and recover without storing failure data', () async {
    var now = DateTime.utc(2030);
    var calls = 0;
    final cache = CatalogMediaCache(
      now: () => now,
      client: MockClient((r) async {
        calls++;
        return http.Response.bytes([1], calls == 1 ? 403 : 200);
      }),
    );
    addTearDown(cache.dispose);
    await expectLater(
      cache.load('https://example.invalid/icon.png'),
      throwsStateError,
    );
    await expectLater(
      cache.load('https://example.invalid/icon.png'),
      throwsStateError,
    );
    expect(calls, 1);
    expect(cache.peek('https://example.invalid/icon.png'), isNull);
    now = now.add(const Duration(seconds: 31));
    await cache.load('https://example.invalid/icon.png');
    expect(calls, 2);
  });
  for (final svg in [false, true]) {
    testWidgets(
      'catalog ${svg ? 'SVG' : 'raster'} icon remount reuses public bytes',
      (tester) async {
        var calls = 0;
        final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
        );
        final cache = CatalogMediaCache(
          client: MockClient((r) async {
            calls++;
            expect(r.headers.containsKey('authorization'), isFalse);
            return svg
                ? http.Response(
                    '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="teal"/></svg>',
                    200,
                    headers: {'content-type': 'image/svg+xml'},
                  )
                : http.Response.bytes(
                    png,
                    200,
                    headers: {'content-type': 'image/png'},
                  );
          }),
        );
        addTearDown(cache.dispose);
        var visible = true;
        late StateSetter update;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              customerCatalogMediaCacheProvider.overrideWithValue(cache),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (_, setState) {
                    update = setState;
                    return visible
                        ? CatalogIcon(
                            appearance: const ServiceAppearance(
                              Colors.teal,
                              Icons.home,
                            ),
                            url:
                                'https://example.invalid/icon.${svg ? 'svg' : 'png'}',
                          )
                        : const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => visible = false);
        await tester.pumpAndSettle();
        update(() => visible = true);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
