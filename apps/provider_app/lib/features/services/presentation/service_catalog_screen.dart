import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/presentation/brand_image.dart';
import 'service_catalog_card.dart';
import 'service_catalog_grid.dart';
import 'service_catalog_loading.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../application/service_providers.dart';
import '../application/service_setup_controller.dart';
import '../domain/provider_service_status.dart';

class ServiceCatalogScreen extends ConsumerStatefulWidget {
  const ServiceCatalogScreen({super.key});
  @override
  ConsumerState<ServiceCatalogScreen> createState() =>
      _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends ConsumerState<ServiceCatalogScreen> {
  bool _refreshing = false;
  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(providerServiceCatalogProvider),
        assignments = ref.watch(providerAssignmentsProvider);
    final completion = ref.watch(providerCompletionControllerProvider);
    final types = catalog.asData?.value,
        owned = assignments.asData?.value,
        progress = completion.asData?.value;
    final busy =
        _refreshing ||
        catalog.isLoading ||
        assignments.isLoading ||
        completion.isLoading;
    Future<void> refresh() async {
      if (busy || _refreshing) return;
      setState(() => _refreshing = true);
      ref.read(providerServiceCatalogProvider.notifier).reload();
      ref.invalidate(providerAssignmentsProvider);
      ref.read(providerCompletionControllerProvider.notifier).reload();
      try {
        await Future.wait([
          ref.read(providerServiceCatalogProvider.future),
          ref.read(providerAssignmentsProvider.future),
          ref.read(providerCompletionControllerProvider.future),
        ]);
      } catch (_) {
        // Existing provider error states remain responsible for presentation.
      } finally {
        if (mounted) setState(() => _refreshing = false);
      }
    }

    Widget content;
    if (catalog.isLoading || assignments.isLoading) {
      content = const ServiceCatalogLoading();
    } else if (types is! Success<List<ProviderServiceType>> ||
        owned is! Success<List<ProviderServiceAssignment>>) {
      content = BThereStateView(
        title: 'Unable to load services',
        message: 'Please try again.',
        action: BThereButton(label: 'Retry', onPressed: busy ? null : refresh),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (completion.isLoading)
            const BThereLoadingState(
              label: 'Loading service progress',
              compact: true,
            )
          else if (progress is Failure<ProviderCompletion> ||
              completion.hasError)
            TextButton(
              onPressed: () => ref
                  .read(providerCompletionControllerProvider.notifier)
                  .reload(),
              child: const Text('Service progress unavailable · Retry'),
            ),
          if (types.value.isEmpty)
            const BThereStateView(
              title: 'No services are available right now.',
              message: 'Check back soon or refresh the service list.',
            ),
          if (types.value.isNotEmpty)
            ServiceCatalogGrid(
              children: [
                for (final service in types.value)
                  Builder(
                    builder: (context) {
                      final a = owned.value
                          .where((a) => a.providerTypeId == service.id)
                          .firstOrNull;
                      final c = progress is Success<ProviderCompletion>
                          ? progress.value.services
                                .where((c) => c.serviceTypeId == service.id)
                                .firstOrNull
                          : null;
                      var status = productServiceStatus(
                        a,
                        c,
                        progressKnown: progress is Success<ProviderCompletion>,
                      );
                      if (a != null && c != null) {
                        final setup = ref
                            .watch(serviceSetupControllerProvider(service.id))
                            .asData
                            ?.value;
                        if (setup is Success<ServiceSetupData>) {
                          status = setup.value.status;
                        }
                      }
                      return ServiceCatalogCard(
                        service: service,
                        status: status,
                        onTap: () => context.go(
                          status == ProviderServiceStatus.approved ||
                                  status ==
                                      ProviderServiceStatus.pendingApproval ||
                                  status == ProviderServiceStatus.inactive ||
                                  status == ProviderServiceStatus.rejected
                              ? AppRoutes.serviceStatus(service.id)
                              : AppRoutes.serviceDetail(service.id),
                        ),
                      );
                    },
                  ),
              ],
            ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => RefreshIndicator(
            onRefresh: refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            const BThereBrandImage(
                              asset: BThereBrandAsset.carePromise,
                              width: 108,
                              semanticLabel: 'B there Provider — Care Promise',
                            ),
                            const Spacer(),
                            Semantics(
                              liveRegion: true,
                              label: busy ? 'Refreshing services' : null,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: IconButton.outlined(
                                  key: const ValueKey('refresh-services'),
                                  tooltip: 'Refresh services',
                                  onPressed: busy ? null : refresh,
                                  icon: busy
                                      ? const ExcludeSemantics(
                                          child: BThereLoadingIndicator(
                                            size: 20,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: BThereColors.primaryAction,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                      Semantics(
                        header: true,
                        label: 'Services',
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
