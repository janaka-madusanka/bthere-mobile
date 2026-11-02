import 'customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'customer_config.dart';
import 'customer_providers.dart';
import '../features/auth/application/customer_auth_controller.dart';
import '../features/auth/presentation/customer_auth_screen.dart';
import '../features/auth/presentation/customer_verification_success_screen.dart';
import '../features/profile/application/customer_profile_controller.dart';
import '../features/profile/presentation/customer_profile_screen.dart';
import '../features/discovery/application/customer_discovery_controller.dart';
import '../features/discovery/presentation/customer_market_screen.dart';
import '../features/discovery/presentation/customer_home_screen.dart';
import '../features/discovery/presentation/customer_services_screen.dart';
import '../features/booking/domain/booking_models.dart';
import '../features/booking/domain/booking_option_draft.dart';
import '../features/booking/presentation/customer_booking_screen.dart';
import '../features/booking/presentation/customer_bookings_screen.dart';
import '../features/wallet/presentation/customer_wallet_screen.dart';

class CustomerBootstrap extends StatefulWidget {
  const CustomerBootstrap({
    super.key,
    this.loadConfig = CustomerConfig.fromEnvironment,
  });
  final CustomerConfig? Function() loadConfig;
  @override
  State<CustomerBootstrap> createState() => _CustomerBootstrapState();
}

class _CustomerBootstrapState extends State<CustomerBootstrap> {
  // Keep this override's identity stable during rebuilds and hot reload.
  // Replacing it recreates auth/discovery and the router at its initial route.
  late final CustomerConfig? _config = widget.loadConfig();
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [customerConfigProvider.overrideWithValue(_config)],
    child: const CustomerApp(),
  );
}

final customerRouterProvider = Provider<GoRouter>(
  (ref) {
    final configured = ref.watch(customerConfigProvider) != null;
    final auth = configured ? ref.watch(customerAuthControllerProvider) : null;
    final profile = configured
        ? ref.watch(customerProfileControllerProvider)
        : null;
    final discovery = configured ? ref.watch(customerDiscoveryProvider) : null;
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: Listenable.merge([auth, profile, discovery]),
      redirect: (_, state) {
        final destination = !configured
            ? '/configuration'
            : auth?.stage == CustomerAuthStage.authenticated
            ? auth?.verificationSuccess != null
                  ? '/verification-success'
                  : profile?.stage == CustomerProfileStage.ready
                  ? ['/profile', '/account'].contains(state.uri.path)
                        ? state.uri.path
                        : discovery?.confirmed == true
                        ? ([
                                    '/market',
                                    '/services',
                                    '/bookings',
                                    '/wallet',
                                  ].contains(state.uri.path) ||
                                  state.uri.path.startsWith('/booking/'))
                              ? state.uri.path
                              : '/home'
                        : discovery?.marketStage == DiscoveryStage.loading ||
                              discovery?.marketStage == DiscoveryStage.idle
                        ? '/'
                        : '/market'
                  : profile?.stage == CustomerProfileStage.missing
                  ? '/profile'
                  : '/'
            : auth?.stage == CustomerAuthStage.signedOut
            ? '/auth'
            : '/';
        return state.uri.path == destination ? null : destination;
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _StartupScreen()),
        GoRoute(path: '/auth', builder: (_, _) => const CustomerAuthScreen()),
        GoRoute(
          path: '/verification-success',
          builder: (_, _) => const CustomerVerificationSuccessScreen(),
        ),
        GoRoute(path: '/account', builder: (_, _) => const _AccountScreen()),
        GoRoute(
          path: '/market',
          builder: (_, _) => const CustomerMarketScreen(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const CustomerHomeScreen()),
        GoRoute(
          path: '/wallet',
          builder: (_, _) => const CustomerWalletScreen(),
        ),
        GoRoute(
          path: '/bookings',
          builder: (_, _) => const CustomerBookingsScreen(),
        ),
        GoRoute(
          path: '/booking/:service/:option',
          builder: (_, state) {
            final key = BookingKey(
              discovery?.activeMarket?.id ?? 0,
              int.tryParse(state.pathParameters['service'] ?? '') ?? 0,
              int.tryParse(state.pathParameters['option'] ?? '') ?? 0,
            );
            return CustomerBookingScreen(
              key: ValueKey(key),
              bookingKey: key,
              initialDraft: state.extra is BookingOptionDraft
                  ? state.extra as BookingOptionDraft
                  : null,
            );
          },
        ),
        GoRoute(
          path: '/services',
          builder: (_, state) => CustomerServicesScreen(
            initialServiceId: int.tryParse(
              state.uri.queryParameters['service'] ?? '',
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const CustomerProfileScreen(),
        ),
        GoRoute(
          path: '/configuration',
          builder: (_, _) => const _ConfigurationScreen(),
        ),
      ],
    );
    ref.onDispose(router.dispose);
    return router;
  },
  dependencies: [
    customerConfigProvider,
    customerAuthControllerProvider,
    customerProfileControllerProvider,
    customerDiscoveryProvider,
  ],
);

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'B there Customer',
    debugShowCheckedModeBanner: false,
    theme: CustomerTheme.light(),
    darkTheme: CustomerTheme.dark(),
    routerConfig: ref.watch(customerRouterProvider),
  );
}

class _StartupScreen extends ConsumerWidget {
  const _StartupScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    final profile = ref.watch(customerProfileControllerProvider);
    final discovery = ref.watch(customerDiscoveryProvider);
    if (auth.stage == CustomerAuthStage.authenticated) {
      return ListenableBuilder(
        listenable: Listenable.merge([profile, auth, discovery]),
        builder: (context, _) => _Page(
          child: profile.stage == CustomerProfileStage.failure
              ? BThereStateView(
                  title: 'Unable to load your profile',
                  message: auth.error ?? profile.error,
                  action: Column(
                    children: [
                      BThereButton(
                        label: 'Retry profile',
                        onPressed: auth.busy ? null : profile.load,
                      ),
                      TextButton(
                        onPressed: auth.busy ? null : auth.logout,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                )
              : BThereLoadingState(
                  label: profile.stage == CustomerProfileStage.ready
                      ? 'Loading your market'
                      : 'Loading your profile',
                ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => _Page(
        child: auth.stage == CustomerAuthStage.failure
            ? BThereStateView(
                title: 'Unable to restore your session',
                message: auth.error,
                action: BThereButton(
                  label: 'Retry',
                  onPressed: auth.busy ? null : auth.restore,
                ),
              )
            : const BThereLoadingState(label: 'Starting B there Customer'),
      ),
    );
  }
}

class _AccountScreen extends ConsumerWidget {
  const _AccountScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => _Page(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, ${auth.user?.username ?? 'Customer'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Customer profile is ready.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            BThereButton(
              label: 'Browse services',
              onPressed: () => context.go('/home'),
            ),
            const SizedBox(height: 12),
            BThereButton(
              label: 'Edit profile',
              onPressed: auth.busy ? null : () => context.go('/profile'),
            ),
            const SizedBox(height: 12),
            BThereButton(
              label: 'My bookings',
              onPressed: () => context.push('/bookings'),
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('customer-account-market'),
              onPressed: () => context.go('/market'),
              child: const Text('Change service area'),
            ),
            if (auth.error case final error?) BThereInlineError(error),
            BThereButton(
              label: 'Sign out',
              loading: auth.busy,
              onPressed: auth.busy ? null : auth.logout,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: auth.busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign out all sessions?'),
                          content: const Text(
                            'This revokes your refresh sessions on all devices.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sign out all'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await auth.logout(all: true);
                      }
                    },
              child: const Text('Sign out all sessions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();
  @override
  Widget build(BuildContext context) => const _Page(
    child: BThereStateView(
      title: 'Unable to start',
      message: 'The app configuration is unavailable. Please contact the development team.',
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: child,
          ),
        ),
      ),
    ),
  );
}
