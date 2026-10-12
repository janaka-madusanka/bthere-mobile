import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/provider_completion_controller.dart';
import '../domain/provider_completion.dart';

class OnboardingGatewayScreen extends ConsumerWidget {
  const OnboardingGatewayScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerCompletionControllerProvider);
    final result = state.asData?.value;
    final loading =
        state.isLoading ||
        (!state.hasError && result is! Failure<ProviderCompletion>);
    return OnboardingPage(
      child: loading
          ? const BThereLoadingState(
              label: 'Checking your account',
              message: 'Finding your next setup step.',
            )
          : BThereStateView(
              title: 'Unable to check your account',
              message: result is Failure<ProviderCompletion>
                  ? result.failure.message
                  : 'Please try again.',
              action: BThereButton(
                label: 'Retry',
                onPressed: () => ref
                    .read(providerCompletionControllerProvider.notifier)
                    .reload(),
              ),
            ),
    );
  }
}

class OnboardingStepScreen extends StatelessWidget {
  const OnboardingStepScreen({required this.step, super.key});
  final ProviderOnboardingStep step;
  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (step) {
      ProviderOnboardingStep.completeProfile => (
        'Complete your profile',
        "We'll use this information to set up your Provider account.",
      ),
      ProviderOnboardingStep.selectMarket => (
        'Select your market',
        'Choose the market where you will provide your services.',
      ),
      ProviderOnboardingStep.selectService => (
        'Select your service',
        'Choose the service you will offer as a Provider.',
      ),
      ProviderOnboardingStep.completeServiceRequirements => (
        'Complete your service requirements',
        'Your service setup needs a few more details before review.',
      ),
      ProviderOnboardingStep.awaitAdminApproval => (
        'Awaiting approval',
        'Your account is waiting for administrator review.',
      ),
      ProviderOnboardingStep.completed => (
        'Setup complete',
        'Your Provider account is ready.',
      ),
    };
    return OnboardingPage(
      child: BThereStateView(title: title, message: message),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'B there Provider',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    child,
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
