final class ProviderMarket {
  const ProviderMarket({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.timezone,
    required this.locale,
    required this.phoneCode,
    required this.status,
  });
  final int id;
  final String name,
      countryCode,
      currencyCode,
      timezone,
      locale,
      phoneCode,
      status;
}
