import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../presentation/onboarding_screen.dart';
import '../application/provider_options_controller.dart';

class ProviderOptionsScreen extends ConsumerWidget {
  const ProviderOptionsScreen({required this.contextIds, super.key});
  final ProviderOptionsContext contextIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = providerOptionsControllerProvider(contextIds),
        state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (_, next) {
      final v = next.asData?.value;
      if (v is Success<ProviderOptionsState> && v.value.saved) {
        context.go(AppRoutes.serviceRequirements);
      }
    });
    final result = state.asData?.value;
    Widget child;
    if (state.isLoading) {
      child = const BThereLoadingState(label: 'Loading service options');
    } else if (result is Success<ProviderOptionsState>) {
      final v = result.value, setup = v.overview.schema.serviceSetup;
      final min = setup.minimumOptionSelections,
          max = setup.maximumOptionSelections;
      child = PopScope(
        canPop: !v.saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose service options',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Select the types of ${v.overview.selected.serviceName} work you want to offer.',
            ),
            if (min != null && max != null)
              Text('Select $min–$max options')
            else if (min != null)
              Text('Select at least $min option${min == 1 ? '' : 's'}')
            else if (max != null)
              Text('Select up to $max options'),
            const SizedBox(height: 16),
            if (v.overview.schema.options.isEmpty)
              const Text('No service options are available. Please retry.'),
            for (final option in v.overview.schema.options)
              Card(
                child: CheckboxListTile(
                  value: v.selected.contains(option.optionId),
                  title: Text(option.name),
                  subtitle:
                      option.fields.isNotEmpty &&
                          v.selected.contains(option.optionId)
                      ? const Text('Additional details required')
                      : null,
                  onChanged: v.saving || v.inconsistent
                      ? null
                      : (_) => controller.toggle(option.optionId),
                ),
              ),
            if (v.validation != null)
              Text(
                v.validation!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (v.failure != null)
              Text(
                v.failure!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            BThereButton(
              label: 'Save options',
              loading: v.saving,
              enabled:
                  !v.saving &&
                  !v.saved &&
                  v.validation == null &&
                  v.overview.schema.options.isNotEmpty,
              onPressed: controller.save,
            ),
            if (v.inconsistent ||
                v.rulesUnavailable ||
                v.overview.schema.options.isEmpty)
              BThereButton(label: 'Retry', onPressed: controller.retry),
            BThereButton(
              label: 'Back to requirements',
              enabled: !v.saving,
              onPressed: () => context.go(AppRoutes.serviceRequirements),
            ),
          ],
        ),
      );
    } else {
      child = BThereStateView(
        title:
            result is Failure<ProviderOptionsState> &&
                result.failure.message == 'Section unavailable'
            ? 'Section unavailable'
            : 'Unable to load service options',
        message: result is Failure<ProviderOptionsState>
            ? (result.failure.message == 'Section unavailable'
                  ? 'Choose an applicable section from your service overview.'
                  : result.failure.message)
            : 'Please try again.',
        action: BThereButton(label: 'Retry', onPressed: controller.retry),
      );
    }
    return OnboardingPage(child: child);
  }
}
