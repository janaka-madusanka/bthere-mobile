# Customer service icon caching

Public catalog icons rendered by CatalogIcon share a session memory cache for both SVG and raster images. Navigation reuses downloaded bytes and concurrent consumers share one request. Catalog service/options metadata was already retained by the discovery controller.

The cache holds at most 64 images / 20 MB, with a 5 MB per-image download limit. It uses Cache-Control max-age (default five minutes), no-cache/no-store, ETag and Last-Modified. Expired images stay visible during conditional revalidation. Failed URLs have a bounded 30-second retry cooldown. Versioned URLs are separate entries.

This is not persistent disk storage: restarting the app can download icons again. Only public catalog assets use this cache; authenticated profile photos and private documents keep their existing pipelines. Image requests do not include API authorization headers. Backend changes are not required; stable versioned URLs and cache headers improve freshness control.

Validation: cache tests cover concurrent requests, expiry/304, LRU bounds, no-store, oversized assets, failure recovery and SVG/PNG widget remounts.
