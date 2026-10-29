import '../../features/onboarding/requirements/options/domain/provider_options_repository.dart';
import '../../features/onboarding/requirements/options/data/provider_options_repository_impl.dart';
import '../../features/onboarding/requirements/options/data/provider_options_remote_data_source.dart';
import '../../features/onboarding/requirements/domain/provider_schema_repository.dart';
import '../../features/onboarding/requirements/data/provider_schema_repository_impl.dart';
import '../../features/onboarding/requirements/data/provider_schema_remote_data_source.dart';
import '../../features/onboarding/services/data/provider_service_remote_data_source.dart';
import '../../features/onboarding/services/data/provider_service_repository_impl.dart';
import '../../features/onboarding/services/domain/provider_service_repository.dart';
import '../../features/onboarding/markets/data/provider_market_remote_data_source.dart';
import '../../features/onboarding/markets/data/provider_market_repository_impl.dart';
import '../../features/onboarding/markets/domain/provider_market_repository.dart';
import '../../features/onboarding/profile/data/provider_profile_remote_data_source.dart';
import '../../features/onboarding/profile/data/provider_profile_repository_impl.dart';
import '../../features/onboarding/profile/domain/provider_profile_repository.dart';
import '../../features/onboarding/data/provider_completion_remote_data_source.dart';
import '../../features/onboarding/data/provider_completion_repository_impl.dart';
import '../../features/onboarding/domain/provider_completion_repository.dart';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/session_access_token_provider.dart';
import '../../core/auth/provider_session_api.dart';
import '../../core/session/app_session_state.dart';
import '../config/app_config.dart';
import '../../features/auth/domain/google_identity_provider.dart';
import '../../features/auth/data/google_sign_in_identity_provider.dart';

final appConfigProvider = Provider<AppConfig?>((ref) => null, dependencies: []);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final googleIdentityProvider = Provider<GoogleIdentityProvider>(
  (ref) => GoogleSignInIdentityProvider(
    serverClientId: ref.watch(appConfigProvider)?.googleServerClientId ?? '',
  ),
  dependencies: [appConfigProvider],
);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => const SecureSessionStorage(store: FlutterSecureKeyValueStore()),
);

final accessTokenProvider = Provider<AccessTokenProvider>(
  (ref) => SessionAccessTokenProvider(
    ref.watch(sessionStorageProvider),
    now: ref.watch(clockProvider),
    refreshSession: ref.watch(providerSessionApiProvider).refresh,
  ),
  dependencies: [
    sessionStorageProvider,
    clockProvider,
    providerSessionApiProvider,
  ],
);

final networkConfigProvider = Provider<NetworkConfig>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config == null) throw StateError('API configuration is required.');
  return NetworkConfig(baseUrl: config.apiBaseUrl);
}, dependencies: [appConfigProvider]);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(networkConfigProvider),
    tokenProvider: ref.watch(accessTokenProvider),
    diagnosticLogger: kDebugMode ? (message) => debugPrint(message) : null,
  );
  ref.onDispose(() => client.close(force: true));
  return client;
}, dependencies: [networkConfigProvider, accessTokenProvider]);

final providerAuthRepositoryProvider = Provider<ProviderAuthRepository>(
  (ref) => ProviderAuthRepositoryImpl(
    client: ref.watch(apiClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    now: ref.watch(clockProvider),
  ),
  dependencies: [apiClientProvider, sessionStorageProvider, clockProvider],
);

final appSessionStateProvider = FutureProvider<AppSessionState>(
  (ref) async {
    if (ref.watch(appConfigProvider) == null) {
      return AppSessionState.configurationFailure;
    }
    try {
      final session = await ref.watch(sessionStorageProvider).read();
      if (!ref.mounted || session == null) {
        return AppSessionState.unauthenticated;
      }
      if (!session.isExpiredAt(ref.read(clockProvider)())) {
        return AppSessionState.authenticated;
      }
      final refreshed = await ref
          .read(providerSessionApiProvider)
          .refresh(session);
      if (!ref.mounted || refreshed == null) {
        return AppSessionState.unauthenticated;
      }
      return refreshed.isExpiredAt(ref.read(clockProvider)())
          ? AppSessionState.unauthenticated
          : AppSessionState.authenticated;
    } catch (_) {
      return AppSessionState.restorationFailure;
    }
  },
  dependencies: [
    appConfigProvider,
    sessionStorageProvider,
    clockProvider,
    providerSessionApiProvider,
  ],
);

final providerCompletionRepositoryProvider =
    Provider<ProviderCompletionRepository>(
      (ref) => ProviderCompletionRepositoryImpl(
        ProviderCompletionRemoteDataSource(ref.watch(apiClientProvider)),
      ),
      dependencies: [apiClientProvider],
    );

final providerProfileRepositoryProvider = Provider<ProviderProfileRepository>(
  (ref) => ProviderProfileRepositoryImpl(
    ProviderProfileRemoteDataSource(ref.watch(apiClientProvider)),
  ),
  dependencies: [apiClientProvider],
);

final providerMarketRepositoryProvider = Provider<ProviderMarketRepository>(
  (ref) => ProviderMarketRepositoryImpl(
    ProviderMarketRemoteDataSource(ref.watch(apiClientProvider)),
  ),
  dependencies: [apiClientProvider],
);

final providerServiceRepositoryProvider = Provider<ProviderServiceRepository>(
  (ref) => ProviderServiceRepositoryImpl(
    ProviderServiceRemoteDataSource(ref.watch(apiClientProvider)),
  ),
  dependencies: [apiClientProvider],
);

final providerSchemaRepositoryProvider = Provider<ProviderSchemaRepository>(
  (ref) => ProviderSchemaRepositoryImpl(
    ProviderSchemaRemoteDataSource(ref.watch(apiClientProvider)),
    diagnosticLogger: kDebugMode ? (message) => debugPrint(message) : null,
  ),
  dependencies: [apiClientProvider],
);

final providerOptionsRepositoryProvider = Provider<ProviderOptionsRepository>(
  (ref) => ProviderOptionsRepositoryImpl(
    ProviderOptionsRemoteDataSource(ref.watch(apiClientProvider)),
  ),
  dependencies: [apiClientProvider],
);
