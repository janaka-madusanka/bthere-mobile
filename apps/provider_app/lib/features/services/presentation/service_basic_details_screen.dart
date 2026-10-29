import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/profile/presentation/provider_profile_screen.dart';
import '../application/service_setup_controller.dart';
import 'service_setup_screen.dart';
import '../../onboarding/profile/data/provider_profile_reader.dart';

import 'package:bthere_design_system/bthere_design_system.dart';

/// Basic Details is a service setup action, never a mandatory landing screen.
class ServiceBasicDetailsScreen extends ConsumerWidget {
  const ServiceBasicDetailsScreen({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serviceSetupControllerProvider(serviceTypeId));
    final result = state.asData?.value;
    if (!state.isLoading &&
        result is Success<ServiceSetupData> &&
        result.value.selectionValid) {
      final profile = ref.watch(providerProfileDetailsProvider);
      final details = profile.asData?.value;
      if (profile.isLoading) {
        return const Scaffold(
          body: Center(child: BThereLoadingState(label: 'Loading profile')),
        );
      }
      if (details is! Success<Map<String, dynamic>>) {
        return Scaffold(
          body: Center(
            child: BThereButton(
              label: 'Retry profile',
              onPressed: () => ref.invalidate(providerProfileDetailsProvider),
            ),
          ),
        );
      }
      return ProviderProfileScreen(
        initialProfile: details.value,
        onBack: () => context.go(AppRoutes.serviceSetup(serviceTypeId)),
        onSaved: () => context.go(AppRoutes.serviceSetup(serviceTypeId)),
      );
    }
    return ServiceSetupScreen(serviceTypeId: serviceTypeId);
  }
}
