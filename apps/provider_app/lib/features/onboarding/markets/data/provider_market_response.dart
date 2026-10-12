import '../domain/provider_market.dart';

List<ProviderMarket> parseActiveProviderMarkets(Object? value) {
  if (value is! List) throw const FormatException('Invalid markets');
  final ids = <int>{};
  final markets = <ProviderMarket>[];
  for (final entry in value) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Invalid market');
    }
    final id = entry['id'];
    if (id is! int || id <= 0 || !ids.add(id)) {
      throw const FormatException('Invalid market ID');
    }
    String text(String key) {
      final field = entry[key];
      if (field is! String || field.trim().isEmpty) {
        throw const FormatException('Invalid market text');
      }
      return field.trim();
    }

    final market = ProviderMarket(
      id: id,
      name: text('name'),
      countryCode: text('countryCode'),
      currencyCode: text('currencyCode'),
      timezone: text('timezone'),
      locale: text('locale'),
      phoneCode: text('phoneCode'),
      status: text('status'),
    );
    if (market.status == 'ACTIVE') markets.add(market);
  }
  return List.unmodifiable(markets);
}
