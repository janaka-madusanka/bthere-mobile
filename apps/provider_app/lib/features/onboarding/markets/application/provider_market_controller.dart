import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/session/app_session_state.dart';
import '../domain/provider_market.dart';

final providerMarketControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ProviderMarketController,
      Result<List<ProviderMarket>>
    >(
      ProviderMarketController.new,
      dependencies: [appSessionStateProvider, providerMarketRepositoryProvider],
    );

final class ProviderMarketController
    extends AsyncNotifier<Result<List<ProviderMarket>>> {
  @override
  Future<Result<List<ProviderMarket>>> build() async {
    final session = await ref.watch(appSessionStateProvider.future);
    if (!ref.mounted || session != AppSessionState.authenticated) {
      return const Failure(
        AppFailure(
          message: 'Sign in to load available markets.',
          code: 'MARKETS_SESSION_REQUIRED',
        ),
      );
    }
    try {
      return await ref
          .watch(providerMarketRepositoryProvider)
          .loadActiveMarkets();
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to load markets. Please try again.',
          code: 'MARKETS_OPERATION_FAILED',
        ),
      );
    }
  }

  void reload() {
    if (!state.isLoading) ref.invalidateSelf();
  }
}
