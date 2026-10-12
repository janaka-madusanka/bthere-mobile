import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/provider_completion_controller.dart';
import '../../presentation/onboarding_screen.dart';
import '../application/provider_service_catalog_controller.dart';
import '../application/provider_service_selection_controller.dart';
import '../domain/provider_service_input.dart';
import '../domain/provider_service_type.dart';

class ProviderServiceScreen extends ConsumerStatefulWidget {
  const ProviderServiceScreen({super.key});
  @override
  ConsumerState<ProviderServiceScreen> createState() =>
      _ProviderServiceScreenState();
}

class _ProviderServiceScreenState extends ConsumerState<ProviderServiceScreen> {
  final _experience = TextEditingController();
  final _form = GlobalKey<FormState>();
  int? _selectedId;
  @override
  void dispose() {
    _experience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(providerServiceCatalogProvider);
    final submission = ref.watch(providerServiceSelectionProvider);
    final result = catalog.asData?.value;
    final services =
        !catalog.isLoading &&
            !catalog.hasError &&
            result is Success<List<ProviderServiceType>>
        ? result.value.where((service) => service.status == 'ACTIVE').toList()
        : <ProviderServiceType>[];
    final selected = services.any((service) => service.id == _selectedId)
        ? _selectedId
        : null;
    final years = ProviderServiceInput.parseExperience(_experience.text);
    final busy = submission.loading;
    final canSubmit =
        !busy &&
        submission.assignment == null &&
        selected != null &&
        years != null;
    Widget catalogContent() {
      if (catalog.isLoading) {
        return const BThereLoadingState(
          label: 'Loading services',
          message: 'Getting your services ready.',
        );
      }
      if (catalog.hasError || result is Failure<List<ProviderServiceType>>) {
        return BThereStateView(
          title: 'Unable to load services',
          message: result is Failure<List<ProviderServiceType>>
              ? result.failure.message
              : 'Please try again.',
          action: BThereButton(
            label: 'Retry',
            variant: BThereButtonVariant.outlined,
            onPressed: () =>
                ref.read(providerServiceCatalogProvider.notifier).reload(),
          ),
        );
      }
      if (services.isEmpty) {
        return const BThereStateView(
          title: 'No services are currently available.',
        );
      }
      return Column(
        children: [
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ServiceTypeTile(
                service: service,
                selected: service.id == selected,
                enabled: !busy && submission.assignment == null,
                onTap: () => setState(() => _selectedId = service.id),
              ),
            ),
        ],
      );
    }

    return PopScope(
      canPop: !busy,
      child: OnboardingPage(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select your service',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the service you want to offer.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              catalogContent(),
              if (selected != null) ...[
                const SizedBox(height: 12),
                BThereTextField(
                  key: const ValueKey('service-experience'),
                  label: 'Years of experience',
                  labelPlacement: BThereFieldLabelPlacement.above,
                  controller: _experience,
                  enabled: !busy && submission.assignment == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: ProviderServiceInput.validateExperience,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (submission.failure != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    submission.failure!.message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (submission.assignment != null) ...[
                const Text(
                  'Your service was added. Recheck your account setup to continue.',
                ),
                const SizedBox(height: 12),
                BThereButton(
                  label: 'Recheck setup',
                  onPressed: () => ref
                      .read(providerCompletionControllerProvider.notifier)
                      .reload(),
                ),
              ] else
                BThereButton(
                  label: 'Continue',
                  loading: busy,
                  onPressed: canSubmit
                      ? () {
                          if (!_form.currentState!.validate()) return;
                          FocusScope.of(context).unfocus();
                          ref
                              .read(providerServiceSelectionProvider.notifier)
                              .submit(
                                ProviderServiceInput(
                                  providerTypeId: selected,
                                  experienceYears: years,
                                ),
                              );
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceTypeTile extends StatelessWidget {
  const ServiceTypeTile({
    required this.service,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });
  final ProviderServiceType service;
  final bool selected, enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const fallback = Icon(Icons.work_outline, size: 32);
    final icon = service.usableIconUri;
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('service-type-${service.id}'),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: icon == null
                      ? fallback
                      : Image.network(
                          icon.toString(),
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (service.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          service.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
