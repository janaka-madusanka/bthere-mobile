import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_app.dart';
import '../../../app/customer_providers.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../profile/application/customer_profile_controller.dart';
import '../application/customer_request_recovery.dart';
import '../data/customer_active_request_notifications.dart';

/// Keeps recovery alive across routes, but never polls in the background.
/// A notification opens a read-only status fetch; it cannot confirm payment.
class CustomerActiveRequestHost extends ConsumerStatefulWidget {
  const CustomerActiveRequestHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<CustomerActiveRequestHost> createState() =>
      _ActiveRequestHostState();
}

class _ActiveRequestHostState extends ConsumerState<CustomerActiveRequestHost>
    with WidgetsBindingObserver {
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _opens;
  Map<String, dynamic>? _pending;
  ActiveRequestNotifications? _gateway;
  CustomerRequestRecovery? _recovery;
  CustomerAuthController? _auth;
  String? _shown;
  final _readiness = <Listenable>[];
  bool _foreground = true, _queued = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gateway != null || ref.read(customerConfigProvider) == null) return;
    _gateway = ref.read(activeRequestNotificationsProvider);
    _recovery = ref.read(customerRequestRecoveryProvider);
    _recovery!.addListener(_schedule);
    _auth = ref.read(customerAuthControllerProvider);
    _auth!.addListener(_schedule);
    _readiness.addAll([
      ref.read(customerDiscoveryProvider),
      ref.read(customerProfileControllerProvider),
    ]);
    for (final item in _readiness) {
      item.addListener(_readyChanged);
    }
    _opens = _gateway!.opens.listen((data) {
      _pending = data;
      _schedule();
    });
    _gateway!.initialOpen().then((data) {
      if (mounted && data != null) {
        _pending = data;
        _schedule();
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_foreground) _refresh();
    });
    Future.microtask(() {
      if (mounted) {
        _refresh();
        _schedule();
      }
    });
  }

  void _readyChanged() {
    if (_foreground) _refresh();
    _schedule();
  }

  bool get _ready =>
      _auth?.stage == CustomerAuthStage.authenticated &&
      ref.read(customerDiscoveryProvider).confirmed;
  void _refresh() {
    if (mounted && _ready) _recovery?.refresh();
  }

  void _schedule() {
    if (!mounted || _queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _sync();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _sync() async {
    final gateway = _gateway;
    if (gateway == null) return;
    final owner = _auth?.user?.id;
    final discovery = ref.read(customerDiscoveryProvider);
    final scope = discovery.selectionStore.apiScope;
    if (_auth?.stage != CustomerAuthStage.authenticated) {
      // Startup checking can still resolve the notification's original account.
      if (_auth?.stage == CustomerAuthStage.signedOut) {
        _shown = null;
        await gateway.clear();
      }
      return;
    }
    if (_foreground &&
        _pending != null &&
        _ready &&
        ref.read(customerProfileControllerProvider).stage ==
            CustomerProfileStage.ready) {
      final data = _pending!;
      _pending = null;
      if (data['owner'] == owner &&
          data['scope'] == scope &&
          data['requestId'] is int &&
          (data['requestId'] as int) > 0) {
        final path = '/booking-requests/${data['requestId']}/payment';
        final router = ref.read(customerRouterProvider);
        if (router.routeInformationProvider.value.uri.path != path) {
          router.push(path);
        }
      }
    }
    if (!_ready ||
        _recovery == null ||
        _recovery!.loading && _recovery!.requests.isEmpty) {
      return;
    }
    final rows = _recovery!.active;
    if (rows.isEmpty) {
      if (_shown != 'empty') {
        _shown = 'empty';
        await gateway.clear();
      }
      return;
    }
    final row = rows.first;
    final status = row['status'];
    final deadline = DateTime.tryParse('${row['confirmationExpiresAt']}');
    final remaining = deadline
        ?.difference(ref.read(customerBookingClockProvider).now())
        .inMilliseconds;
    if (status == 'AWAITING_CUSTOMER_CONFIRMATION' &&
        remaining != null &&
        remaining <= 0) {
      if (_shown != 'expired') {
        _shown = 'expired';
        await gateway.clear();
      }
      return;
    }
    final payload = <String, dynamic>{
      'owner': owner,
      'scope': scope,
      'requestId': row['requestId'],
      'title': !_foreground
          ? 'Your booking request is active'
          : status == 'MATCHING'
          ? 'Finding a provider'
          : status == 'AWAITING_CUSTOMER_CONFIRMATION'
          ? 'Provider found - confirm payment'
          : 'Checking your payment',
      'body':
          'Request #${row['requestId']} \u00b7 Tap to check the latest status',
      'matching': status == 'MATCHING',
      'remainingMs': ?remaining,
    };
    // Updating only semantic transitions avoids notification churn every poll.
    final identity =
        '$owner|$scope|${row['requestId']}|$status|${row['confirmationExpiresAt']}|$_foreground';
    if (_shown == identity) return;
    _shown = identity;
    await gateway.show(payload);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _refresh();
      _schedule();
    } else {
      // Flutter does not schedule UI frames while paused. Update the OS notice
      // directly without starting network reads or navigating in the background.
      unawaited(_sync());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _opens?.cancel();
    _recovery?.removeListener(_schedule);
    _auth?.removeListener(_schedule);
    for (final item in _readiness) {
      item.removeListener(_readyChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Retain the autoDispose recovery controller while the app is mounted.
    if (ref.watch(customerConfigProvider) != null) {
      ref.watch(customerRequestRecoveryProvider);
    }
    if (_gateway != null) _schedule();
    return widget.child;
  }
}
