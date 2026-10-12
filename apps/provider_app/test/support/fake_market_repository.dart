import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/markets/domain/provider_market.dart';
import 'package:provider_app/features/onboarding/markets/domain/provider_market_repository.dart';
import 'package:provider_app/features/onboarding/markets/data/provider_market_response.dart';

Map<String, dynamic> marketJson({
  int id = 7,
  String name = 'Test market',
  String status = 'ACTIVE',
}) => {
  'id': id,
  'name': name,
  'countryCode': 'LK',
  'currencyCode': 'LKR',
  'timezone': 'Asia/Colombo',
  'locale': 'en-LK',
  'phoneCode': '+94',
  'status': status,
  'createdAt': 'ignored',
  'updatedAt': 'ignored',
};

final class FakeMarketRepository implements ProviderMarketRepository {
  int calls = 0;
  Completer<Result<List<ProviderMarket>>>? pending;
  bool throwOnLoad = false;
  Result<List<ProviderMarket>> result = Success(
    parseActiveProviderMarkets([marketJson()]),
  );
  @override
  Future<Result<List<ProviderMarket>>> loadActiveMarkets() async {
    calls++;
    if (throwOnLoad) throw StateError('private synthetic market exception');
    return pending == null ? result : pending!.future;
  }
}
