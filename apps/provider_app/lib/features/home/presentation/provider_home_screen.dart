import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/providers/app_providers.dart';
import '../../account/application/provider_account_controller.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../../services/application/service_providers.dart';
import 'provider_home_widgets.dart';
import 'provider_home_accessible.dart';

class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(providerAssignmentsProvider);
    ref.invalidate(providerCompletionControllerProvider);
    ref.invalidate(providerServiceCatalogProvider);
    ref.invalidate(providerAccountProvider);
    ref.invalidate(homeServiceOptionsProvider);
    await ref.read(providerAssignmentsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registration is independent of setup completion and verification status.
    final assignments = ref.watch(providerAssignmentsProvider);
    final completion = ref
        .watch(providerCompletionControllerProvider)
        .asData
        ?.value;
    final catalog = ref.watch(providerServiceCatalogProvider).asData?.value;
    final account = ref.watch(providerAccountProvider).asData?.value;
    final services = catalog is Success<List<ProviderServiceType>>
        ? catalog.value
        : <ProviderServiceType>[];
    final progress = completion is Success<ProviderCompletion>
        ? completion.value
        : null;
    final result = assignments.asData?.value;
    final registered =
        result is Success<List<ProviderServiceAssignment>> &&
        result.value.isNotEmpty;
    final foreground = registered ? const Color(0xFF0B3037) : homeInk;
    if (MediaQuery.textScalerOf(context).scale(14) > 18.2) {
      return HomeAccessible(
        assignments: result is Success<List<ProviderServiceAssignment>>
            ? result.value
            : null,
        loading: assignments.isLoading,
        username: account?.username,
        onRefresh: () => _refresh(ref),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: registered ? 'PublicSans' : 'PublicSans',
          bodyColor: foreground,
          displayColor: foreground,
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: DecoratedBox(
          decoration: homeGradient,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const HomeScale(child: HomeHeader()),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      21 * MediaQuery.sizeOf(context).width / 430,
                    ),
                    child: ColoredBox(
                      color: Colors.white,
                      child: RefreshIndicator(
                        onRefresh: () => _refresh(ref),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: HomeScale(
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontFamily: registered
                                    ? 'PublicSans'
                                    : 'PublicSans',
                                color: foreground,
                                fontSize: 14,
                                height: 1.3,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (assignments.isLoading)
                                    const SizedBox(
                                      height: 284,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  else if (result
                                      is! Success<
                                        List<ProviderServiceAssignment>
                                      >)
                                    SizedBox(
                                      height: 284,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Unable to load your registered services.',
                                            ),
                                            TextButton(
                                              onPressed: () => _refresh(ref),
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (!registered)
                                    const HomeWelcome()
                                  else ...[
                                    HomeGreeting(
                                      username: account?.username,
                                      now: ref.read(clockProvider)().toLocal(),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        1,
                                        16,
                                        0,
                                      ),
                                      child: Column(
                                        children: [
                                          HomeHeading(
                                            'Your Registered Services',
                                            registered: true,
                                            action: 'Manage Services',
                                            onTap: () =>
                                                context.go(AppRoutes.services),
                                          ),
                                          const SizedBox(height: 6),
                                          for (final assignment in result.value)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: HomeRegisteredService(
                                                assignment: assignment,
                                                completion: progress?.services
                                                    .where(
                                                      (s) =>
                                                          s.assignmentId ==
                                                          assignment
                                                              .assignmentId,
                                                    )
                                                    .firstOrNull,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (result
                                      is Success<
                                        List<ProviderServiceAssignment>
                                      >) ...[
                                    HomeCategories(
                                      registered: registered,
                                      services: services,
                                    ),
                                    if (!registered)
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          18,
                                          12,
                                          17,
                                          10,
                                        ),
                                        child: HomeCommunity(),
                                      ),
                                  ],
                                  HomeResources(registered: registered),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
