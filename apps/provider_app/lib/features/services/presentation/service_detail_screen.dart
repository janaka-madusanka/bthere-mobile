import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../application/service_detail_controller.dart';
import '../domain/provider_service_status.dart';
import '../domain/sub_service_rules.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  final _experience = TextEditingController();
  bool _initialized = false;
  @override
  void dispose() {
    _experience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = serviceDetailControllerProvider(widget.serviceTypeId),
        state = ref.watch(provider),
        controller = ref.read(provider.notifier);
    ref.listen(provider, (_, next) {
      final value = next.asData?.value;
      if (value is Success<ServiceDetailState> && value.value.saved) {
        context.go(AppRoutes.serviceSetup(widget.serviceTypeId));
      }
    });
    final result = state.asData?.value;
    Widget child;
    if (state.isLoading) {
      _initialized = false;
      child = const BThereLoadingState(label: 'Loading service detail');
    } else if (result is Success<ServiceDetailState>) {
      final v = result.value;
      final progress = ref
          .watch(providerCompletionControllerProvider)
          .asData
          ?.value;
      final serviceCompletion = progress is Success<ProviderCompletion>
          ? progress.value.services
                .where((s) => s.serviceTypeId == widget.serviceTypeId)
                .firstOrNull
          : null;
      final status = productServiceStatus(v.assignment, serviceCompletion);
      if (status == ProviderServiceStatus.approved ||
          status == ProviderServiceStatus.pendingApproval ||
          status == ProviderServiceStatus.inactive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go(AppRoutes.serviceStatus(widget.serviceTypeId));
          }
        });
        return const OnboardingPage(
          child: BThereLoadingState(label: 'Loading service status'),
        );
      }
      if (!_initialized ||
          (v.assignment != null && _experience.text != v.experience)) {
        _experience.text = v.experience;
        _initialized = true;
      }
      final names = <String, int>{};
      for (final option in v.schema.options) {
        names.update(
          option.name.trim().toLowerCase(),
          (n) => n + 1,
          ifAbsent: () => 1,
        );
      }
      final sameLabels = <String, int>{};
      for (final option in v.schema.options) {
        final label =
            '${option.name.trim().toLowerCase()}|${humanizeOptionCode(option.code).toLowerCase()}';
        sameLabels.update(label, (n) => n + 1, ifAbsent: () => 1);
      }
      child = PopScope(
        canPop: !v.busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              v.service.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (v.service.description != null) Text(v.service.description!),
            const SizedBox(height: 24),
            Text(
              'Choose the services you provide',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(subServiceGuidance(v.schema)),
            if (sameLabels.values.any((count) => count > 1))
              const Text(
                'Some sub-services need clearer catalog labels. Each variant remains a separate selection.',
              ),
            const SizedBox(height: 12),
            if (v.schema.options.isEmpty)
              const Text(
                'No sub-services are configured for this main service.',
              ),
            for (final option in v.schema.options)
              Card(
                child: CheckboxListTile(
                  key: ValueKey('sub-service-${option.optionId}'),
                  title: Text(option.name),
                  subtitle:
                      (names[option.name.trim().toLowerCase()] ?? 0) > 1 ||
                          (v.selected.contains(option.optionId) &&
                              option.fields.isNotEmpty)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((names[option.name.trim().toLowerCase()] ?? 0) >
                                1)
                              Text(humanizeOptionCode(option.code)),
                            if ((sameLabels['${option.name.trim().toLowerCase()}|${humanizeOptionCode(option.code).toLowerCase()}'] ??
                                    0) >
                                1)
                              Text('Variant ${option.optionId}'),
                            if (v.selected.contains(option.optionId) &&
                                option.fields.isNotEmpty)
                              const Text('Additional details required'),
                          ],
                        )
                      : null,
                  value: v.selected.contains(option.optionId),
                  onChanged: v.busy || v.inconsistent
                      ? null
                      : (_) => controller.toggle(option.optionId),
                ),
              ),
            const SizedBox(height: 16),
            BThereTextField(
              label: 'Years of experience',
              labelPlacement: BThereFieldLabelPlacement.above,
              controller: _experience,
              enabled: !v.busy && v.assignment == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: controller.experience,
            ),
            if (v.assignment != null)
              const Text(
                'Experience is saved for this main service. Updating it is not available yet.',
              ),
            if (v.validation != null)
              Text(
                v.validation!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (v.failure != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  v.failure!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            BThereButton(
              label: v.failure == null ? 'Continue' : 'Retry',
              loading: v.busy,
              enabled: !v.busy && !v.saved && v.validation == null,
              onPressed: controller.continueSetup,
            ),
            if (v.schema.options.isEmpty ||
                v.inconsistent ||
                (v.schema.serviceSetup.optionsRequired &&
                    v.schema.serviceSetup.minimumOptionSelections == null))
              BThereButton(
                label: 'Reload service',
                onPressed: controller.retry,
              ),
            BThereButton(
              label: 'Back to services',
              enabled: !v.busy,
              onPressed: () => context.go(AppRoutes.services),
            ),
          ],
        ),
      );
    } else {
      child = BThereStateView(
        title: 'Unable to load service',
        message: 'Please try again.',
        action: BThereButton(label: 'Retry', onPressed: controller.retry),
      );
    }
    return OnboardingPage(child: child);
  }
}
