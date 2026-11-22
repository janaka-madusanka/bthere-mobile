import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final customerCatalogMediaCacheProvider = Provider<CatalogMediaCache>((ref) {
  final cache = CatalogMediaCache();
  ref.onDispose(cache.dispose);
  return cache;
});

class CatalogMedia {
  CatalogMedia(this.bytes, this.svg, this.expires, this.etag, this.modified);
  final Uint8List bytes;
  final bool svg;
  final DateTime expires;
  final String? etag, modified;
}

/// Public catalog icons only. No API tokens, private documents or profile data.
/// Bounded session LRU; concurrent consumers share one download. Expired assets
/// are conditionally revalidated while the widget keeps its existing picture.
class CatalogMediaCache {
  CatalogMediaCache({
    http.Client? client,
    DateTime Function()? now,
    this.maximumEntries = 64,
    this.maximumBytes = 20 * 1024 * 1024,
    this.maximumFileBytes = 5 * 1024 * 1024,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _now;
  final int maximumEntries, maximumBytes, maximumFileBytes;
  final _entries = <String, CatalogMedia>{};
  final _pending = <String, Future<CatalogMedia>>{};
  final _failedUntil = <String, DateTime>{};
  int _bytes = 0;
  bool _disposed = false;

  CatalogMedia? peek(String url) {
    final value = _entries.remove(url);
    if (value != null) _entries[url] = value;
    return value;
  }

  bool fresh(CatalogMedia value) => _now().isBefore(value.expires);

  Future<CatalogMedia> load(String url) {
    final current = peek(url);
    if (current != null && fresh(current)) return Future.value(current);
    if (_pending[url] case final Future<CatalogMedia> pending) return pending;
    if (_disposed || (_failedUntil[url]?.isAfter(_now()) ?? false)) {
      return Future.error(StateError('Catalog image temporarily unavailable'));
    }
    final future = _download(url, current);
    _pending[url] = future;
    return future;
  }

  Duration _ttl(String control) {
    if (control.contains('no-cache')) return Duration.zero;
    final seconds = int.tryParse(
      RegExp(r'(?:^|,)\s*max-age\s*=\s*"?(\d+)')
              .firstMatch(control)
              ?.group(1) ??
          '',
    );
    return Duration(seconds: (seconds ?? 300).clamp(0, 86400));
  }

  Future<CatalogMedia> _download(String url, CatalogMedia? previous) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid catalog image');
      }
      final request = http.Request('GET', uri);
      if (previous?.etag case final String etag) {
        request.headers['If-None-Match'] = etag;
      }
      if (previous?.modified case final String date) {
        request.headers['If-Modified-Since'] = date;
      }
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final control = (response.headers['cache-control'] ?? '').toLowerCase();
      final expiry = _now().add(_ttl(control));
      CatalogMedia value;
      if (response.statusCode == 304 && previous != null) {
        await response.stream.drain<void>().timeout(
          const Duration(seconds: 15),
        );
        value = CatalogMedia(
          previous.bytes,
          previous.svg,
          expiry,
          response.headers['etag'] ?? previous.etag,
          response.headers['last-modified'] ?? previous.modified,
        );
      } else {
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > maximumFileBytes) {
          await response.stream.listen((_) {}).cancel();
          throw StateError('Catalog image unavailable');
        }
        final type = (response.headers['content-type'] ?? '').toLowerCase();
        if (type.contains('text/html')) {
          await response.stream.listen((_) {}).cancel();
          throw const FormatException('Invalid catalog image response');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 15),
        )) {
          if (bytes.length + chunk.length > maximumFileBytes) {
            throw StateError('Catalog image too large');
          }
          bytes.add(chunk);
        }
        if (bytes.isEmpty) throw const FormatException('Empty catalog image');
        value = CatalogMedia(
          bytes.takeBytes(),
          type.contains('image/svg+xml') ||
              uri.path.toLowerCase().endsWith('.svg'),
          expiry,
          response.headers['etag'],
          response.headers['last-modified'],
        );
      }
      if (!_disposed) {
        _failedUntil.remove(url);
        final old = _entries.remove(url);
        if (old != null) _bytes -= old.bytes.length;
        if (!control.contains('no-store') &&
            maximumEntries > 0 &&
            value.bytes.length <= maximumBytes) {
          while (_entries.isNotEmpty &&
              (_entries.length >= maximumEntries ||
                  _bytes + value.bytes.length > maximumBytes)) {
            _bytes -= _entries.remove(_entries.keys.first)!.bytes.length;
          }
          _entries[url] = value;
          _bytes += value.bytes.length;
        }
      }
      return value;
    } catch (_) {
      if (!_disposed) {
        _failedUntil.remove(url);
        while (_failedUntil.length >= maximumEntries &&
            _failedUntil.isNotEmpty) {
          _failedUntil.remove(_failedUntil.keys.first);
        }
        if (maximumEntries > 0) {
          _failedUntil[url] = _now().add(const Duration(seconds: 30));
        }
      }
      rethrow;
    } finally {
      _pending.remove(url);
    }
  }

  void dispose() {
    _disposed = true;
    _entries.clear();
    _pending.clear();
    _failedUntil.clear();
    _client.close();
  }
}
