import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../application/provider_account_controller.dart';

class ProviderAccountScreen extends ConsumerWidget {
  const ProviderAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(providerAccountProvider);
    final completion = ref.watch(providerCompletionControllerProvider);
    final signOut = ref.watch(providerSignOutProvider);
    final user = account.asData?.value;
    final progress = completion.asData?.value;
    final busy = signOut.busy;
    final signOutError = signOut.error;

    Future<void> refresh() async {
      if (busy || account.isLoading || completion.isLoading) return;
      ref.invalidate(providerAccountProvider);
      ref.read(providerCompletionControllerProvider.notifier).reload();
      try {
        await Future.wait([
          ref.read(providerAccountProvider.future),
          ref.read(providerCompletionControllerProvider.future),
        ]);
      } catch (_) {
        // Render the providers' safe error states below.
      }
    }

    Future<void> confirmSignOut() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access your provider account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref.read(providerSignOutProvider.notifier).signOut();
      }
    }

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: BThereColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Profile'),
          backgroundColor: BThereColors.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              key: const ValueKey('refresh-profile'),
              tooltip: 'Refresh profile',
              onPressed: busy || account.isLoading || completion.isLoading
                  ? null
                  : refresh,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (account.isLoading)
                        const BThereLoadingState(label: 'Loading your account')
                      else if (account.hasError)
                        BThereStateView(
                          title: 'Unable to load account details',
                          message: 'Please try again.',
                          action: TextButton(
                            onPressed: busy ? null : refresh,
                            child: const Text('Retry account details'),
                          ),
                        )
                      else ...[
                        _IdentityCard(user: user),
                        const SizedBox(height: 20),
                        _Section(
                          title: 'Account details',
                          child: user == null
                              ? const Text(
                                  'Account details are not available for this session.',
                                )
                              : Column(
                                  children: [
                                    _Detail(
                                      icon: Icons.person_outline,
                                      label: 'Username',
                                      value: user.username,
                                    ),
                                    _Detail(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: _available(user.email),
                                    ),
                                    _Detail(
                                      icon: Icons.badge_outlined,
                                      label: 'Account ID',
                                      value: '#${user.id}',
                                    ),
                                    _Detail(
                                      icon: Icons.shield_outlined,
                                      label: 'Account status',
                                      value: _readable(user.status),
                                    ),
                                    _Detail(
                                      icon: Icons.work_outline,
                                      label: 'Account roles',
                                      value: user.roles
                                          .map(_readable)
                                          .join(', '),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _Section(
                        title: 'Provider setup',
                        child: completion.isLoading
                            ? const BThereLoadingState(
                                label: 'Loading setup progress',
                                compact: true,
                              )
                            : progress is Success<ProviderCompletion>
                            ? _SetupSummary(value: progress.value)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Unable to load setup progress.'),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => ref
                                              .read(
                                                providerCompletionControllerProvider
                                                    .notifier,
                                              )
                                              .reload(),
                                    child: const Text('Retry setup progress'),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      const _Section(
                        title: 'Personal provider details',
                        child: Text(
                          'Personal details are not available here yet.',
                        ),
                      ),
                      const SizedBox(height: 20),
                      BThereButton(
                        label: 'Manage services',
                        onPressed: busy
                            ? null
                            : () => context.go(AppRoutes.services),
                      ),
                      const SizedBox(height: 12),
                      if (signOutError != null) ...[
                        BThereInlineError(signOutError),
                        const SizedBox(height: 12),
                      ],
                      BThereButton(
                        key: const ValueKey('profile-sign-out'),
                        label: 'Sign out',
                        variant: BThereButtonVariant.outlined,
                        loading: busy,
                        onPressed: busy ? null : confirmSignOut,
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

String _available(String? text) =>
    text == null || text.trim().isEmpty ? 'Not available' : text;
String _readable(String value) => value
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? '' : '${word[0]}${word.substring(1).toLowerCase()}',
    )
    .join(' ');

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});
  final SessionUser? user;
  @override
  Widget build(BuildContext context) {
    final email = user?.email;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BThereColors.primaryAction.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const ExcludeSemantics(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_outline_rounded,
                size: 40,
                color: BThereColors.primaryAction,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.username ?? 'Provider account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (email != null && email.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'B there Provider',
            style: TextStyle(color: BThereColors.primaryAction),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: BThereColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: BThereColors.primaryAction, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SetupSummary extends StatelessWidget {
  const _SetupSummary({required this.value});
  final ProviderCompletion value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${value.completionPercentage.round()}% complete',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: value.completionPercentage.toDouble() / 100,
        minHeight: 6,
        borderRadius: BorderRadius.circular(8),
      ),
      const SizedBox(height: 12),
      for (final item in [
        ('Provider details', value.profileCompleted),
        ('Market selection', value.marketSelected),
        ('Service selection', value.serviceSelected),
      ])
        _Detail(
          icon: item.$2
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          label: item.$1,
          value: item.$2 ? 'Complete' : 'Pending',
        ),
      const Divider(height: 24),
      Text(switch (value.nextStep) {
        ProviderOnboardingStep.completeProfile =>
          'Next: Complete provider details',
        ProviderOnboardingStep.selectMarket => 'Next: Select your market',
        ProviderOnboardingStep.selectService => 'Next: Select your service',
        ProviderOnboardingStep.completeServiceRequirements =>
          'Next: Complete service requirements',
        ProviderOnboardingStep.awaitAdminApproval =>
          'Awaiting administrator approval',
        ProviderOnboardingStep.completed => 'Provider setup completed',
      }),
    ],
  );
}
