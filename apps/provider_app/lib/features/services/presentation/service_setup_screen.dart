import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../onboarding/requirements/domain/provider_requirement_section.dart';
import '../application/service_setup_controller.dart';
import '../domain/provider_service_status.dart';

class ServiceSetupScreen extends ConsumerWidget {
  const ServiceSetupScreen({
    required this.serviceTypeId,
    this.section,
    this.showStatus = false,
    this.viewOnly = false,
    super.key,
  });
  final int serviceTypeId;
  final ProviderRequirementSection? section;
  final bool showStatus, viewOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = serviceSetupControllerProvider(serviceTypeId),
        state = ref.watch(provider),
        controller = ref.read(provider.notifier),
        result = state.asData?.value;
    Widget child;
    if (state.isLoading) {
      child = const BThereLoadingState(label: 'Loading service setup');
    } else if (result is Success<ServiceSetupData>) {
      final v = result.value, status = v.status;
      final review =
          status == ProviderServiceStatus.pendingApproval ||
          status == ProviderServiceStatus.approved ||
          status == ProviderServiceStatus.inactive;
      if (!showStatus && !viewOnly && section == null && review) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(AppRoutes.serviceStatus(serviceTypeId));
          }
        });
      }
      if (!v.selectionValid && !review && !showStatus) {
        child = BThereStateView(
          title: 'Choose your sub-services',
          message: 'Select and save valid services you provide before continuing setup.',
          action: BThereButton(
            label: 'Choose services you provide',
            onPressed: () => context.go(AppRoutes.serviceDetail(serviceTypeId)),
          ),
        );
      } else if (showStatus || (review && !viewOnly)) {
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              v.assignment.providerTypeName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              status?.label ?? 'Status unavailable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(switch (status) {
              ProviderServiceStatus.pendingApproval => 'Your information has been submitted and is waiting for review.',
              ProviderServiceStatus.approved => 'This service is approved.',
              ProviderServiceStatus.rejected =>
                'Your service needs attention before it can be approved.',
              ProviderServiceStatus.inactive =>
                'This service is currently inactive.',
              _ => 'Complete the information required for this service.',
            }),
            if (status == ProviderServiceStatus.rejected &&
                v.assignment.rejectionReason != null)
              Text('Service review: ${v.assignment.rejectionReason!}'),
            if (status == ProviderServiceStatus.setupRequired ||
                status == ProviderServiceStatus.rejected)
              BThereButton(
                label: 'View service setup',
                onPressed: () =>
                    context.go(AppRoutes.serviceSetup(serviceTypeId)),
              ),
            if (status == ProviderServiceStatus.approved)
              BThereButton(
                label: 'View setup information',
                onPressed: () => context.go(
                  AppRoutes.serviceSetup(serviceTypeId, view: true),
                ),
              ),
            BThereButton(
              label: 'Refresh status',
              onPressed: controller.refresh,
            ),
            BThereButton(
              label: 'Back to services',
              onPressed: () => context.go(AppRoutes.services),
            ),
          ],
        );
      } else if (section != null) {
        final valid = v.rows.any((r) => r.section == section);
        child = Column(
          children: [
            Text(
              valid ? section!.label : 'Section unavailable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              valid
                  ? '${v.assignment.providerTypeName} setup will be available here soon.'
                  : 'Choose an applicable section from this service setup.',
            ),
            if (valid && section == ProviderRequirementSection.additional) ...[
              for (final field in v.fields)
                ListTile(
                  title: Text(field.label),
                  subtitle: Text(field.required ? 'Required' : 'Optional'),
                ),
            ],
            BThereButton(
              label: 'Back to setup',
              onPressed: () =>
                  context.go(AppRoutes.serviceSetup(serviceTypeId)),
            ),
          ],
        );
      } else {
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${v.assignment.providerTypeName} Setup',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Complete the information required to offer your selected ${v.assignment.providerTypeName} services.',
            ),
            const SizedBox(height: 16),
            if (!v.completion.profileCompleted && !viewOnly)
              Card(
                child: ListTile(
                  title: const Text('Basic details'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(
                    '${AppRoutes.serviceSetup(serviceTypeId)}/profile',
                  ),
                ),
              ),
            if (!v.completion.marketSelected && !viewOnly)
              Card(
                child: ListTile(
                  title: const Text('Market information'),
                  subtitle: const Text('Select your market in Basic details.'),
                  onTap: () => context.go(
                    '${AppRoutes.serviceSetup(serviceTypeId)}/profile',
                  ),
                ),
              ),
            Text(
              '${v.rows.where((r) => r.completed).length} of ${v.rows.length} sections completed',
            ),
            Text(
              'Overall account setup: ${v.completion.completionPercentage}%',
            ),
            for (final row in v.rows)
              Card(
                child: ListTile(
                  title: Text(row.section.label),
                  subtitle: Text(
                    '${row.completed ? 'Completed' : 'Needs attention'}${row.level == null ? '' : ' · ${row.level!.name}'}',
                  ),
                  trailing: viewOnly ? null : const Icon(Icons.chevron_right),
                  onTap: viewOnly
                      ? null
                      : () => context.go(
                          '${AppRoutes.serviceSetup(serviceTypeId)}/${row.section.slug}',
                        ),
                ),
              ),
            BThereButton(
              label: 'View service status',
              onPressed: () =>
                  context.go(AppRoutes.serviceStatus(serviceTypeId)),
            ),
            if (!viewOnly)
              BThereButton(
                label: 'Change services you provide',
                onPressed: () =>
                    context.go(AppRoutes.serviceDetail(serviceTypeId)),
              ),
            BThereButton(label: 'Refresh setup', onPressed: controller.refresh),
            BThereButton(
              label: 'Back to services',
              onPressed: () => context.go(AppRoutes.services),
            ),
          ],
        );
      }
    } else {
      child = BThereStateView(
        title: 'Unable to load service setup',
        message: 'Please try again.',
        action: BThereButton(label: 'Retry', onPressed: controller.refresh),
      );
    }
    return OnboardingPage(child: child);
  }
}
