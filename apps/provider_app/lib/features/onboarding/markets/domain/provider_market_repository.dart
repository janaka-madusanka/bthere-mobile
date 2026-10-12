import 'package:bthere_common/bthere_common.dart';

import 'provider_market.dart';

abstract interface class ProviderMarketRepository {
  Future<Result<List<ProviderMarket>>> loadActiveMarkets();
}
