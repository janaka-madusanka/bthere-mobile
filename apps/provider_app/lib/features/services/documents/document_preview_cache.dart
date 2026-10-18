import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import 'document_models.dart';

final documentPreviewCacheProvider =
    NotifierProvider<DocumentPreviewCache, Map<String, Uint8List>>(
      DocumentPreviewCache.new,
      dependencies: [appSessionStateProvider],
    );

class DocumentPreviewCache extends Notifier<Map<String, Uint8List>> {
  @override
  Map<String, Uint8List> build() {
    ref.watch(appSessionStateProvider);
    return {};
  }

  Future<void> remember(String key, DocumentFile file) async {
    if (file.size > 10000000 ||
        ![
          'jpg',
          'jpeg',
          'png',
          'webp',
        ].contains(file.name.split('.').last.toLowerCase())) {
      return;
    }
    try {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        if (bytes.length + chunk.length > 10000000) return;
        bytes.add(chunk);
      }
      if (!ref.mounted) return;
      // Keep a bounded in-memory preview cache; original documents stay in storage.
      final entries = Map<String, Uint8List>.of(state);
      while (entries.values.fold<int>(0, (n, v) => n + v.length) +
                  bytes.length >
              20000000 &&
          entries.isNotEmpty) {
        entries.remove(entries.keys.first);
      }
      state = {...entries, key: bytes.takeBytes()};
    } catch (_) {
      /* Preview failures never change successful upload state. */
    }
  }
}
