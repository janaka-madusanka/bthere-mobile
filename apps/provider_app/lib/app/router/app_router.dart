import 'package:flutter/widgets.dart';

import '../presentation/provider_shell.dart';
import '../presentation/provider_tabs.dart';
import '../presentation/provider_placeholder_screen.dart';
import '../../features/home/presentation/provider_home_screen.dart';
import '../../features/account/presentation/provider_account_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/app_session_state.dart';
import '../../features/startup/presentation/startup_screen.dart';
import '../../features/auth/application/email_verification_controller.dart';
import '../../features/auth/presentation/auth_entry_screen.dart';
import '../../features/auth/presentation/email_registration_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/services/presentation/service_basic_details_screen.dart';
import '../../features/onboarding/requirements/domain/provider_requirement_section.dart';
import '../../features/services/presentation/service_catalog_screen.dart';
import '../../features/services/presentation/service_detail_screen.dart';
import '../../features/services/presentation/service_registration_screen.dart';
import '../../features/services/presentation/service_setup_screen.dart';
import '../../features/services/presentation/application_status_screen.dart';
import '../providers/app_providers.dart';
import 'app_routes.dart';
import '../../features/onboarding/application/provider_entry_gate.dart';
import '../../features/onboarding/profile/presentation/provider_profile_screen.dart';

import 'package:bthere_common/bthere_common.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(appSessionStateProvider, (_, next) => refresh.value++);
  ref.listen(providerEntryGateProvider, (_, next) => refresh.value++);
  int serviceId(GoRouterState state) =>
      int.tryParse(state.pathParameters['serviceTypeId'] ?? '') ?? 0;
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.startup,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session =
          ref.read(appSessionStateProvider).asData?.value ??
          AppSessionState.checking;
      final path = state.uri.path;
      if (session == AppSessionState.authenticated) {
        final gate = ref.read(providerEntryGateProvider);
        final result = gate.asData?.value;
        if (gate.isLoading || result is! Success<bool>) {
          return path == AppRoutes.startup ? null : AppRoutes.startup;
        }
        if (result.value) {
          return path == AppRoutes.profile ? null : AppRoutes.profile;
        }
        // Service completion remains status data after account prerequisites.
        if (ProviderTab.values.any((tab) => tab.path == path) ||
            path == '/services/register' ||
            path == AppRoutes.onboarding ||
            (path != AppRoutes.profile &&
                RegExp(r'^/onboarding/[^/]+$').hasMatch(path)) ||
            RegExp(r'^/onboarding/service-requirements/[^/]+$')
                .hasMatch(path) ||
            RegExp(r'^/services/[1-9][0-9]*(/.*)?$').hasMatch(path)) {
          return null;
        }
        return AppRoutes.home;
      }
      if (session != AppSessionState.unauthenticated) {
        return path == AppRoutes.startup ? null : AppRoutes.startup;
      }
      if (path == AppRoutes.emailVerification) {
        final extra = state.extra;
        return extra is EmailVerificationContext &&
                extra.email.trim().isNotEmpty
            ? null
            : AppRoutes.emailRegistration;
      }
      return path == AppRoutes.auth || path == AppRoutes.emailRegistration
          ? null
          : AppRoutes.auth;
    },
    routes: [
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, _) => ProviderProfileScreen(
          initialOnboarding: true,
          onSaved: () {
            ref.read(providerEntryGateProvider.notifier).profileSaved();
            context.go(AppRoutes.home);
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ProviderShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const ProviderHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.services,
                builder: (_, _) => const ServiceCatalogScreen(),
                routes: [
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'register',
                    builder: (_, _) => const ServiceRegistrationScreen(),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId',
                    builder: (_, state) =>
                        ServiceDetailScreen(serviceTypeId: serviceId(state)),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId/register',
                    builder: (_, state) => ServiceRegistrationScreen(
                      serviceTypeId: serviceId(state),
                      initialStep: state.uri.queryParameters['details'] == '1'
                          ? 2
                          : 0,
                      optionId: int.tryParse(
                        state.uri.queryParameters['optionId'] ?? '',
                      ),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId/setup',
                    builder: (_, state) => ServiceSetupScreen(
                      serviceTypeId: serviceId(state),
                      viewOnly: state.uri.queryParameters['view'] == '1',
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId/status',
                    builder: (_, state) => ApplicationStatusScreen(
                      serviceTypeId: serviceId(state),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId/setup/profile',
                    builder: (_, state) => ServiceBasicDetailsScreen(
                      serviceTypeId: serviceId(state),
                    ),
                  ),
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':serviceTypeId/setup/documents',
                    builder: (_, state) => ServiceRegistrationScreen(
                      serviceTypeId: serviceId(state),
                      initialStep: 3,
                    ),
                  ),
                  for (final section in ProviderRequirementSection.values.where(
                    (s) =>
                        s != ProviderRequirementSection.options &&
                        s != ProviderRequirementSection.documents,
                  ))
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: ':serviceTypeId/setup/${section.slug}',
                      builder: (_, state) => ServiceRegistrationScreen(
                        serviceTypeId: serviceId(state),
                        initialStep:
                            section ==
                                    ProviderRequirementSection.certificates ||
                                section == ProviderRequirementSection.education
                            ? 3
                            : 2,
                      ),
                    ),
                ],
              ),
            ],
          ),
          for (final tab in [ProviderTab.requests, ProviderTab.messages])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (_, _) => ProviderPlaceholderScreen(tab: tab),
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (_, _) => const ProviderAccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (_, _) => const StartupScreen(),
      ),
      GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthEntryScreen()),
      GoRoute(
        path: AppRoutes.emailRegistration,
        builder: (_, _) => const EmailRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (_, state) => EmailVerificationScreen(
          email: (state.extra! as EmailVerificationContext).email,
        ),
      ),
      // Retired wizard links migrate to Services without executing old steps.
      GoRoute(path: '/onboarding', redirect: (_, _) => AppRoutes.services),
      GoRoute(
        path: '/onboarding/:step',
        redirect: (_, _) => AppRoutes.services,
      ),
      GoRoute(
        path: '/onboarding/service-requirements/:section',
        redirect: (_, _) => AppRoutes.services,
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}, dependencies: [appSessionStateProvider, providerEntryGateProvider]);
