import 'client/api_client.dart';

/// Public market content, partitioned by market and audience for one minute.
class MarketBannerRepository {
  MarketBannerRepository(this.client);
  final ApiClient client;
  final _cache = <String, (DateTime, List<MarketBanner>)>{};
  Future<List<MarketBanner>> load(int marketId, String audience) async {
    if (marketId <= 0 || !{'CUSTOMER', 'PROVIDER'}.contains(audience)) {
      throw ArgumentError('Invalid banner market or audience');
    }
    final key = '$marketId/$audience';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 1)) {
      return cached.$2.where((b) => !b.expired).toList();
    }
    final response = await client.get<Object?>(
      '/markets/$marketId/banners',
      queryParameters: {'audience': audience},
    );
    final data = response.data;
    if (data is! Map ||
        data['marketId'] != marketId ||
        data['banners'] is! List) {
      throw const FormatException('Invalid banner response');
    }
    final banners = <MarketBanner>[];
    for (final raw in data['banners'] as List) {
      if (raw is! Map) continue;
      final banner = MarketBanner.parse(raw);
      if (banner != null && !banner.expired) banners.add(banner);
    }
    // Preserve server order, including equal sortOrder values.
    _cache[key] = (DateTime.now(), banners);
    return banners;
  }
}

class MarketBanner {
  const MarketBanner(
    this.id,
    this.title,
    this.imageUrl,
    this.linkType,
    this.serviceId,
    this.optionId,
    this.linkUrl,
    this.endsAt,
  );
  final int id;
  final String title, imageUrl, linkType;
  final int? serviceId, optionId;
  final Uri? linkUrl;
  final DateTime? endsAt;
  bool get expired =>
      endsAt != null && !endsAt!.isAfter(DateTime.now().toUtc());
  static Uri? https(Object? value) {
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? uri : null;
  }

  static MarketBanner? parse(Map raw) {
    final id = raw['bannerId'];
    final title = raw['title'];
    final image = https(raw['imageUrl']);
    if (id is! int || id <= 0 || title is! String || image == null) return null;
    final type = raw['linkType'] as String? ?? 'NONE';
    final service = raw['serviceTypeId'] is int
        ? raw['serviceTypeId'] as int
        : null;
    final option = raw['optionId'] is int ? raw['optionId'] as int : null;
    final url = https(raw['linkUrl']);
    final valid =
        type == 'NONE' ||
        type == 'URL' && url != null ||
        type == 'SERVICE' && service != null && service > 0 ||
        type == 'OPTION' &&
            service != null &&
            service > 0 &&
            option != null &&
            option > 0;
    final end = raw['endsAt'];
    final endsAt = end is String ? DateTime.tryParse(end) : null;
    if (end != null && endsAt == null) return null;
    return MarketBanner(
      id,
      title,
      image.toString(),
      valid ? type : 'NONE',
      service,
      option,
      url,
      endsAt,
    );
  }
}
