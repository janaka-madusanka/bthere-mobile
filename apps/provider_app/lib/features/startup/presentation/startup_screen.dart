import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../../core/session/app_session_state.dart';

import 'package:bthere_common/bthere_common.dart';

import '../../onboarding/application/provider_entry_gate.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSessionStateProvider);
    final session = state.asData?.value;
    final gate = ref.watch(providerEntryGateProvider);
    final gateResult = gate.asData?.value;
    final gateFailed =
        session == AppSessionState.authenticated &&
        (gate.hasError || (!gate.isLoading && gateResult is Failure<bool>));
    final message = gateFailed
        ? (gateResult is Failure<bool>
              ? gateResult.failure.message
              : entryCheckFailure.message)
        : switch (session) {
            AppSessionState.configurationFailure => 'Configuration required: supply a valid BTHERE_API_BASE_URL with --dart-define.',
            AppSessionState.restorationFailure => 'Unable to restore the secure session. Please restart the app to try again.',
            _ =>
              state.hasError
                  ? 'Unable to start the app. Please restart to try again.'
                  : null,
          };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BThereSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BThereStateView(title: 'B there Provider', message: message),
                const SizedBox(height: BThereSpacing.md),
                if (gateFailed)
                  BThereButton(
                    label: 'Retry account setup',
                    onPressed: () =>
                        ref.read(providerEntryGateProvider.notifier).retry(),
                  ),
                if (message == null)
                  const BThereLoadingState(label: 'Starting B there Provider'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
