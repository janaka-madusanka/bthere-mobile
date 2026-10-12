import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';

final providerAssignmentsProvider =
    FutureProvider<Result<List<ProviderServiceAssignment>>>(
      (ref) async {
        final session = await ref.watch(appSessionStateProvider.future);
        if (!ref.mounted || session != AppSessionState.authenticated) {
          return const Failure(
            AppFailure(message: 'Sign in to view your services.'),
          );
        }
        try {
          return await ref
              .watch(providerServiceRepositoryProvider)
              .loadAssignments();
        } catch (_) {
          return const Failure(
            AppFailure(
              message: 'Unable to load your services. Please try again.',
            ),
          );
        }
      },
      dependencies: [
        appSessionStateProvider,
        providerServiceRepositoryProvider,
      ],
    );
final serviceSchemaProvider = FutureProvider.autoDispose
    .family<Result<ProviderOnboardingSchema>, int>(
      (ref, id) async {
        final session = await ref.watch(appSessionStateProvider.future);
        if (!ref.mounted ||
            session != AppSessionState.authenticated ||
            id <= 0) {
          return const Failure(
            AppFailure(message: 'This service is unavailable.'),
          );
        }
        try {
          return await ref
              .watch(providerSchemaRepositoryProvider)
              .loadSchema(id);
        } catch (_) {
          return const Failure(
            AppFailure(
              message: 'Unable to load service setup. Please try again.',
            ),
          );
        }
      },
      dependencies: [appSessionStateProvider, providerSchemaRepositoryProvider],
    );
