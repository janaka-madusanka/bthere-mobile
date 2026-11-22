import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../../app/customer_app.dart';
import '../../../app/customer_providers.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../profile/application/customer_profile_controller.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../application/customer_booking_notifications.dart';
import '../application/customer_request_recovery.dart';
import '../../messages/application/customer_chat_controller.dart';

final customerMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>(
      (ref) => GlobalKey<ScaffoldMessengerState>(),
    );

class CustomerNotificationHost extends ConsumerStatefulWidget {
  const CustomerNotificationHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<CustomerNotificationHost> createState() =>
      _CustomerNotificationHostState();
}

class _CustomerNotificationHostState
    extends ConsumerState<CustomerNotificationHost>
    with WidgetsBindingObserver {
  CustomerBookingNotifications? c;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        c != null &&
        ref.read(customerAuthControllerProvider).stage ==
            CustomerAuthStage.authenticated) {
      ref.read(customerRequestRecoveryProvider).refresh();
      ref.read(customerChatInboxProvider)?.refresh();
      c!.syncRegistration();
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (c == null && ref.read(customerConfigProvider) != null) {
      c = ref.read(customerBookingNotificationsProvider);
      c!.addListener(changed);
      c!.start();
    }
  }

  void changed() {
    if (mounted &&
        ref.read(customerAuthControllerProvider).stage !=
            CustomerAuthStage.authenticated) {
      ref.read(customerMessengerKeyProvider).currentState?.clearSnackBars();
    }
    if (mounted) setState(() {});
  }

  void deliver() {
    final notice = c?.notice;
    if (notice == null || !mounted) return;
    final auth = ref.read(customerAuthControllerProvider),
        profile = ref.read(customerProfileControllerProvider),
        discovery = ref.read(customerDiscoveryProvider);
    if (auth.stage != CustomerAuthStage.authenticated ||
        profile.stage != CustomerProfileStage.ready ||
        !discovery.confirmed) {
      return;
    }
    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    c!.clearNotice();
    final recipient = auth.user?.id;
    final router = ref.read(customerRouterProvider);
    if (notice.opened) {
      router.push(notice.path);
    } else {
      ref
          .read(customerMessengerKeyProvider)
          .currentState
          ?.showSnackBar(
            SnackBar(
              content: Text(
                notice.chat
                    ? 'You have a new booking message.'
                    : 'Your booking has an update.',
              ),
              action: SnackBarAction(
                label: 'View',
                onPressed: () {
                  if (ref.read(customerAuthControllerProvider).user?.id ==
                          recipient &&
                      ref.read(customerAuthControllerProvider).stage ==
                          CustomerAuthStage.authenticated) {
                    router.push(notice.path);
                  }
                },
              ),
            ),
          );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c?.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (c == null) return widget.child;
    return ListenableBuilder(
      listenable: Listenable.merge([
        ref.watch(customerAuthControllerProvider),
        ref.watch(customerProfileControllerProvider),
        ref.watch(customerDiscoveryProvider),
      ]),
      builder: (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) deliver();
        });
        return widget.child;
      },
    );
  }
}

Future<void> showCustomerNotificationSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _NotificationSettings(),
    );

class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(customerBookingNotificationsProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (_, _) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Booking notifications',
                  style: CustomerTypography.section,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Get updates when your provider accepts, arrives or finishes your service.',
                  style: CustomerTypography.body,
                ),
                const SizedBox(height: 12),
                Text(
                  c.deviceId != null
                      ? 'Booking notifications are registered on this device.'
                      : 'Enable notifications to receive booking updates on this device.',
                  style: CustomerTypography.compact,
                ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      c.error!,
                      style: CustomerTypography.compact.copyWith(
                        color: CustomerColors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: c.busy ? null : c.enable,
                  child: Text(
                    c.busy
                        ? 'Enabling…'
                        : c.deviceId != null
                        ? 'Check notification settings'
                        : 'Enable notifications',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
