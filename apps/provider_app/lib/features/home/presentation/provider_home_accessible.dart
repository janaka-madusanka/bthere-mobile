import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../services/domain/provider_service_status.dart';
import 'provider_home_widgets.dart';

/// At large system text sizes, use intrinsic rows instead of fixed Figma cards.
class HomeAccessible extends StatelessWidget {
  const HomeAccessible({
    super.key,
    required this.assignments,
    required this.loading,
    required this.onRefresh,
    this.username,
  });
  final List<ProviderServiceAssignment>? assignments;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String? username;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: homeGradient,
    child: SafeArea(
      bottom: false,
      child: Column(
        children: [
          const HomeScale(child: HomeHeader()),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: Material(
                color: Colors.white,
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (loading)
                        const Center(child: CircularProgressIndicator())
                      else if (assignments == null) ...[
                        const Text('Unable to load your registered services.'),
                        TextButton(
                          onPressed: onRefresh,
                          child: const Text('Retry'),
                        ),
                      ] else if (assignments!.isEmpty) ...[
                        Text(
                          'Your skills create better days',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Find opportunities, help people, and grow your income.',
                        ),
                        TextButton(
                          onPressed: () => context.go('${AppRoutes.services}/register'),
                          child: const Text('Register your first service'),
                        ),
                      ] else ...[
                        Text(
                          username ?? 'Your dashboard',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const Text('Your Registered Services'),
                        for (final assignment in assignments!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(assignment.providerTypeName),
                            subtitle: Text(
                              productServiceStatus(assignment, null)?.label ??
                                  'Status unavailable',
                            ),
                            onTap: () => context.push(
                              AppRoutes.serviceDetail(assignment.providerTypeId),
                            ),
                          ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.services),
                          child: const Text('Manage Services'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.services),
                        child: const Text('Popular services'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Helpful resources'),
                      for (final resource in [
                        'Provider guide',
                        'Safety tips',
                        'FAQs',
                      ])
                        TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const SafeArea(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Resource content is not available yet.',
                                ),
                              ),
                            ),
                          ),
                          child: Text(resource),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
