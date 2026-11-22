import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/customer_config.dart';
import '../app/customer_providers.dart';
import '../app/customer_theme.dart';
import '../features/auth/application/customer_auth_controller.dart';
import '../features/auth/data/customer_auth_service.dart';
import '../features/profile/application/customer_profile_controller.dart';
import '../features/profile/data/customer_profile_repository.dart';
import '../features/discovery/application/customer_discovery_controller.dart';
import '../features/discovery/data/customer_discovery_repository.dart';
import '../features/discovery/data/customer_market_selection_store.dart';
import '../features/discovery/domain/customer_discovery.dart';
import '../features/booking/presentation/customer_booking_details_screen.dart';
import '../features/booking/presentation/customer_booking_providers.dart';
import '../features/booking/presentation/customer_booking_map.dart';
import '../features/messages/presentation/customer_messages_screen.dart';
import 'booking_ui_lab_backend.dart';
import 'booking_ui_lab_map.dart';

export 'booking_ui_lab_backend.dart' show BookingLabScene;

/// A separate entry point supplies every boundary. The normal app does not
/// import this file, and release/profile builds do not render the lab.
class BookingUiLab extends StatefulWidget {
  const BookingUiLab({super.key, this.initialScene = BookingLabScene.ready});
  final BookingLabScene initialScene;
  @override
  State<BookingUiLab> createState() => _LabState();
}

class _LabState extends State<BookingUiLab> {
  late BookingLabScene scene = widget.initialScene;
  int revision = 0;
  double scale = 1;
  bool narrow = false;
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('UI lab is debug only.'))),
      );
    }
    return _LabSession(
      key: ValueKey('${scene.id}-$revision'),
      scene: scene,
      scale: scale,
      narrow: narrow,
      onScene: (value) => setState(() {
        scene = value;
        revision++;
      }),
      onReset: () => setState(() => revision++),
      onScale: () => setState(
        () => scale = scale == 1
            ? 1.3
            : scale == 1.3
            ? 2
            : 1,
      ),
      onWidth: () => setState(() => narrow = !narrow),
    );
  }
}

class BookingLabRuntime {
  BookingLabRuntime(BookingLabScene scene)
    : backend = BookingLabBackend(scene) {
    final user = SessionUser(
      id: 12,
      username: 'ui-lab',
      status: 'ACTIVE',
      roles: ['CUSTOMER'],
    );
    storage = LabSessionStorage(
      AuthSession(
        accessToken: 'ui-lab-not-a-real-token',
        refreshToken: 'ui-lab-not-a-real-refresh',
        tokenType: 'Bearer',
        expiresAt: backend.base.add(const Duration(days: 2)),
        user: user,
      ),
    );
    client = ApiClient(
      config: NetworkConfig(baseUrl: api),
      adapter: backend,
      tokenProvider: CustomerAccessTokenProvider(
        storage,
        now: () => backend.now,
      ),
    );
    service = CustomerAuthService(client, storage, now: () => backend.now);
    auth = CustomerAuthController(service);
    profile = CustomerProfileController(
      CustomerProfileRepository(service),
      auth,
    );
    market = CustomerMarketSelectionStore(LabKeyValueStore(), apiScope: api);
    discovery = CustomerDiscoveryController(
      CustomerDiscoveryRepository(service),
      auth,
      profile,
      selectionStore: market,
    );
    // Seed the unrelated auth/catalog boundary without touching secure storage.
    // Booking widgets and their repositories/controllers remain the real ones.
    auth.user = user;
    auth.stage = CustomerAuthStage.authenticated;
    profile.stage = CustomerProfileStage.ready;
    const area = CustomerMarket(
      id: 1,
      name: 'Sri Lanka',
      countryCode: 'LK',
      currencyCode: 'LKR',
      timezone: 'Asia/Colombo',
    );
    discovery.markets = [area];
    discovery.activeMarket = area;
    discovery.candidate = area;
    discovery.marketStage = discovery.serviceStage = DiscoveryStage.ready;
    discovery.services = [
      const CustomerService(
        id: 1,
        name: 'Caregiver',
        description: 'Sample care service',
        imageUrl: null,
        coverImage: false,
        accessStatus: 'ELIGIBLE',
        action: 'CONTINUE',
        reasons: [],
      ),
    ];
  }
  static const api = 'https://booking-ui-lab.invalid/api/v1';
  final BookingLabBackend backend;
  late final LabSessionStorage storage;
  late final ApiClient client;
  late final CustomerAuthService service;
  late final CustomerAuthController auth;
  late final CustomerProfileController profile;
  late final CustomerDiscoveryController discovery;
  late final CustomerMarketSelectionStore market;
  void dispose() {
    discovery.dispose();
    profile.dispose();
    auth.dispose();
    client.close(force: true);
  }
}

class _LabSession extends StatefulWidget {
  const _LabSession({
    super.key,
    required this.scene,
    required this.scale,
    required this.narrow,
    required this.onScene,
    required this.onReset,
    required this.onScale,
    required this.onWidth,
  });
  final BookingLabScene scene;
  final double scale;
  final bool narrow;
  final ValueChanged<BookingLabScene> onScene;
  final VoidCallback onReset, onScale, onWidth;
  @override
  State<_LabSession> createState() => _SessionState();
}

class _SessionState extends State<_LabSession> {
  late final BookingLabRuntime runtime = BookingLabRuntime(widget.scene);
  final messenger = GlobalKey<ScaffoldMessengerState>();
  late final router = GoRouter(
    initialLocation: '/bookings/${BookingLabBackend.jobId}',
    routes: [
      GoRoute(
        path: '/bookings/:jobId',
        builder: (_, _) =>
            const CustomerBookingDetailsScreen(jobId: BookingLabBackend.jobId),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const CustomerMessagesScreen(),
      ),
      GoRoute(
        path: '/messages/:jobId',
        builder: (_, _) =>
            const CustomerChatScreen(jobId: BookingLabBackend.jobId),
      ),
      GoRoute(
        path: '/booking-requests/:requestId/payment',
        builder: (_, _) => const _LaterReview(),
      ),
      for (final path in [
        '/lab',
        '/home',
        '/opportunities',
        '/services',
        '/wallet',
        '/account',
      ])
        GoRoute(
          path: path,
          builder: (_, _) => _SceneList(onSelected: widget.onScene),
        ),
    ],
  );
  @override
  void dispose() {
    router.dispose();
    runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      customerConfigProvider.overrideWithValue(
        CustomerConfig(apiBaseUrl: BookingLabRuntime.api),
      ),
      customerClockProvider.overrideWithValue(() => runtime.backend.now),
      customerSessionStorageProvider.overrideWithValue(runtime.storage),
      customerApiClientProvider.overrideWithValue(runtime.client),
      customerAuthServiceProvider.overrideWithValue(runtime.service),
      customerAuthControllerProvider.overrideWithValue(runtime.auth),
      customerProfileControllerProvider.overrideWithValue(runtime.profile),
      customerDiscoveryProvider.overrideWithValue(runtime.discovery),
      customerMarketSelectionStoreProvider.overrideWithValue(runtime.market),
      customerMapBuilderProvider.overrideWithValue(BookingLabMap.new),
      customerProviderCallLauncherProvider.overrideWithValue((_) async {
        messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Sample call only. No phone app was opened.'),
          ),
        );
        return true;
      }),
    ],
    child: MaterialApp.router(
      title: 'Booking UI Lab',
      debugShowCheckedModeBanner: false,
      theme: CustomerTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: messenger,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final width = widget.narrow
            ? 320.0.clamp(0, media.size.width).toDouble()
            : media.size.width;
        return Column(
          children: [
            Material(
              color: const Color(0xFFFFF3D5),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 42,
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('ui-lab-scenes'),
                        onPressed: () => router.go('/lab'),
                        icon: const Icon(
                          Icons.tune_rounded,
                          size: 20,
                          semanticLabel: 'Choose booking scenario',
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'UI LAB · sample data',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('ui-lab-scale'),
                        onPressed: widget.onScale,
                        child: Text(
                          'Aa ${widget.scale}×',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ui-lab-width'),
                        onPressed: widget.onWidth,
                        icon: Icon(
                          widget.narrow
                              ? Icons.phone_android
                              : Icons.stay_current_portrait,
                          size: 18,
                          semanticLabel: 'Toggle 320px width',
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('ui-lab-reset'),
                        onPressed: widget.onReset,
                        icon: const Icon(
                          Icons.restart_alt,
                          size: 20,
                          semanticLabel: 'Reset sample scenario',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: MediaQuery(
                    data: media.copyWith(
                      size: Size(
                        width,
                        media.size.height - media.padding.top - 42,
                      ),
                      padding: media.padding.copyWith(top: 0),
                      textScaler: TextScaler.linear(widget.scale),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SceneList extends StatelessWidget {
  const _SceneList({required this.onSelected});
  final ValueChanged<BookingLabScene> onSelected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Booking UI scenarios')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Start with Ready. These are the real booking widgets with sample data. Each reset discards sample actions.',
          style: CustomerTypography.body,
        ),
        const SizedBox(height: 16),
        for (final scene in BookingLabScene.values)
          Card(
            child: ListTile(
              key: ValueKey('ui-lab-scene-${scene.id}'),
              title: Text(scene.label, style: CustomerTypography.card),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(scene),
            ),
          ),
      ],
    ),
  );
}

class _LaterReview extends StatelessWidget {
  const _LaterReview();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment UI review')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Payment actions are a later review step. This lab never opens a live checkout.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Back to sample booking'),
          ),
        ],
      ),
    ),
  );
}
