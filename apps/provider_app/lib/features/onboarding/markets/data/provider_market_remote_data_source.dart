import 'package:bthere_network/bthere_network.dart';

final class ProviderMarketRemoteDataSource {
  const ProviderMarketRemoteDataSource(this._client);
  final ApiClient _client;
  Future<Object?> loadMarkets() async =>
      (await _client.get<Object?>('/markets', requiresAuth: true)).data;
}
