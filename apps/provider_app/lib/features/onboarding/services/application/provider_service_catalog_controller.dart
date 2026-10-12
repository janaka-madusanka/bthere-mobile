import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../../../core/session/app_session_state.dart';
import '../domain/provider_service_type.dart';

final providerServiceCatalogProvider =
    AsyncNotifierProvider.autoDispose<
      ProviderServiceCatalogController,
      Result<List<ProviderServiceType>>
    >(
      ProviderServiceCatalogController.new,
      dependencies: [
        appSessionStateProvider,
        providerServiceRepositoryProvider,
      ],
    );

final class ProviderServiceCatalogController
    extends AsyncNotifier<Result<List<ProviderServiceType>>> {
  @override
  Future<Result<List<ProviderServiceType>>> build() async {
    final session = await ref.watch(appSessionStateProvider.future);
    if (!ref.mounted || session != AppSessionState.authenticated) {
      return const Failure(
        AppFailure(
          message: 'Sign in to view available services.',
          code: 'SERVICE_SESSION_REQUIRED',
        ),
      );
    }
    try {
      return await ref
          .watch(providerServiceRepositoryProvider)
          .loadActiveServices();
    } catch (_) {
      return const Failure(
        AppFailure(
          message: 'Unable to load services. Please try again.',
          code: 'SERVICE_CATALOG_FAILED',
        ),
      );
    }
  }

  void reload() {
    if (!state.isLoading) ref.invalidateSelf();
  }
}
