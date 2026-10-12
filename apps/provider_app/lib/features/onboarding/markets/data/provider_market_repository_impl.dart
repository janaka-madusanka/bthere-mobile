import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_market.dart';
import '../domain/provider_market_repository.dart';
import 'provider_market_remote_data_source.dart';
import 'provider_market_response.dart';

final class ProviderMarketRepositoryImpl implements ProviderMarketRepository {
  const ProviderMarketRepositoryImpl(this._remote);
  final ProviderMarketRemoteDataSource _remote;
  @override
  Future<Result<List<ProviderMarket>>> loadActiveMarkets() async {
    try {
      return Success(parseActiveProviderMarkets(await _remote.loadMarkets()));
    } on NetworkException catch (error) {
      return Failure(error.toAppFailure());
    } on FormatException {
      return const Failure(
        AppFailure(
          message: 'Unable to read available markets. Please try again.',
          code: 'MARKETS_INVALID_RESPONSE',
        ),
      );
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to load markets. Please try again.',
          code: 'MARKETS_OPERATION_FAILED',
        ),
      );
    }
  }
}
