import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/customer_catalog_media_cache.dart';

class CatalogMediaImage extends ConsumerStatefulWidget {
  const CatalogMediaImage({
    super.key,
    required this.url,
    required this.fallback,
  });
  final String url;
  final Widget fallback;
  @override
  ConsumerState<CatalogMediaImage> createState() => _CatalogMediaImageState();
}

class _CatalogMediaImageState extends ConsumerState<CatalogMediaImage> {
  CatalogMedia? media;
  int epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CatalogMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  void _load() {
    final ticket = ++epoch;
    final cache = ref.read(customerCatalogMediaCacheProvider);
    media = cache.peek(widget.url);
    if (media != null && cache.fresh(media!)) return;
    cache
        .load(widget.url)
        .then(
          (value) {
            if (mounted && ticket == epoch) setState(() => media = value);
          },
          onError: (Object _) {
            /* Keep an existing image, otherwise the icon fallback. */
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final value = media;
    if (value == null) return widget.fallback;
    return value.svg
        ? SvgPicture.memory(
            value.bytes,
            theme: const SvgTheme(),
            fit: BoxFit.contain,
            placeholderBuilder: (_) => widget.fallback,
            errorBuilder: (_, _, _) => widget.fallback,
          )
        : Image.memory(
            value.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          );
  }
}
