import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../auth/data/customer_auth_service.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/data/customer_market_selection_store.dart';
import '../data/customer_booking_repository.dart';
import '../data/customer_push_gateway.dart';
import 'customer_booking_controller.dart';
import 'customer_booking_history.dart';
import '../../wallet/application/customer_wallet_controller.dart';
import 'customer_request_recovery.dart';
import '../../messages/application/customer_chat_controller.dart';

final customerBookingNotificationsProvider =
    Provider<CustomerBookingNotifications>(
      (ref) {
        final c = CustomerBookingNotifications(
          ref.read(customerBookingRepositoryProvider),
          ref.read(customerAuthControllerProvider),
          ref.read(customerPushGatewayProvider),
          ref.read(customerMarketSelectionStoreProvider),
          onRefresh: () {
            ref.read(customerChatInboxProvider)?.refresh();
            final owner = ref.read(customerAuthControllerProvider).user?.id;
            if (owner != null) {
              ref.invalidate(customerBookingHistoryProvider(owner));
              ref.invalidate(customerWalletProvider);
              ref.read(customerRequestRecoveryProvider).refresh();
            }
          },
        );
        ref.onDispose(c.dispose);
        return c;
      },
      dependencies: [
        customerBookingRepositoryProvider,
        customerAuthControllerProvider,
        customerPushGatewayProvider,
        customerMarketSelectionStoreProvider,
        customerBookingHistoryProvider,
        customerWalletProvider,
        customerRequestRecoveryProvider,
        customerChatInboxProvider,
      ],
    );

class BookingNotice {
  BookingNotice(
    this.eventId,
    this.requestId,
    this.path,
    this.opened, {
    this.chat = false,
  });
  final int eventId, requestId;
  final String path;
  final bool opened;
  final bool chat;
}

class CustomerBookingNotifications extends ChangeNotifier {
  CustomerBookingNotifications(
    this.repository,
    this.auth,
    this.gateway,
    this.store, {
    required this.onRefresh,
  }) {
    logoutHook = unregister;
    auth.beforeLogout = logoutHook;
    auth.addListener(identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final CustomerPushGateway gateway;
  final CustomerMarketSelectionStore store;
  final VoidCallback onRefresh;
  late final Future<void> Function() logoutHook;
  final List<StreamSubscription<dynamic>> subscriptions = [];
  final seen = <int>{},
      opened = <int>{},
      inFlight = <int>{},
      pendingOpen = <int>{};
  BookingNotice? notice;
  String? error;
  bool configured = false,
      busy = false,
      disposed = false,
      initialized = false,
      bindingReady = false,
      signingOut = false;
  int? owner, deviceId;
  int epoch = 0;
  Future<void> registration = Future.value();
  bool current(int ticket, int? user) =>
      !disposed &&
      epoch == ticket &&
      user != null &&
      owner == user &&
      auth.user?.id == user &&
      auth.stage == CustomerAuthStage.authenticated;
  String key(int user) =>
      'bthere.customer.push.v1.${Uri.encodeComponent(store.apiScope)}.$user';
  void emit() {
    if (!disposed) notifyListeners();
  }

  void identityChanged() {
    if (auth.stage != CustomerAuthStage.authenticated ||
        owner != null && owner != auth.user?.id) {
      epoch++;
      owner = null;
      deviceId = null;
      bindingReady = false;
      notice = null;
      seen.clear();
      opened.clear();
      inFlight.clear();
      pendingOpen.clear();
      gateway.deleteToken().catchError((_) {});
      emit();
    }
    if (auth.stage == CustomerAuthStage.authenticated) {
      if (owner == null) {
        start();
      } else if (signingOut && !auth.busy) {
        // Logout did not complete; the retained session still needs delivery.
        signingOut = false;
        syncRegistration();
      }
    }
  }

  Future<void> start() async {
    if (disposed ||
        owner != null ||
        auth.stage != CustomerAuthStage.authenticated) {
      return;
    }
    owner = auth.user?.id;
    bindingReady = false;
    signingOut = false;
    final ticket = epoch, user = owner;
    try {
      if (!initialized) {
        configured = await gateway.initialize();
        if (!current(ticket, user)) return;
        if (!configured || disposed) {
          emit();
          return;
        }
        if (!initialized) {
          initialized = true;
          subscriptions.add(
            gateway.tokens.listen((_) => syncRegistration(), onError: (_) {}),
          );
          subscriptions.add(gateway.messages.listen(handle, onError: (_) {}));
        }
      }
      if (!current(ticket, user)) return;
      final binding = '${store.apiScope}|$user';
      final previousBinding = await store.store.read(
        'bthere.customer.push.binding.v1',
      );
      if (!current(ticket, user)) return;
      if (previousBinding != null && previousBinding != binding) {
        await gateway.deleteToken();
      }
      final savedDevice = int.tryParse(
        await store.store.read(key(user!)) ?? '',
      );
      if (!current(ticket, user)) return;
      deviceId = savedDevice;
      bindingReady = true;
      await syncRegistration();
      if (!current(ticket, user)) return;
      final initial = await gateway.initialMessage();
      if (initial != null) await handle(initial);
    } catch (_) {
      if (current(ticket, user)) {
        error = 'Booking notifications are currently unavailable.';
        emit();
      }
    }
  }

  Future<void> enable() async {
    if (busy || disposed) return;
    busy = true;
    error = null;
    emit();
    try {
      configured = await gateway.initialize();
      if (!configured) {
        error = 'Push notifications are not configured for this app build.';
        return;
      }
      if (!initialized || !bindingReady) {
        owner = null;
        await start();
      }
      await syncRegistration(askPermission: true);
    } finally {
      busy = false;
      emit();
    }
  }

  Future<void> syncRegistration({bool askPermission = false}) {
    final ticket = epoch, user = owner;
    final operation = registration.catchError((_) {}).then((_) async {
      if (!current(ticket, user) ||
          !configured ||
          !bindingReady ||
          signingOut) {
        return;
      }
      try {
        final token = await gateway.token(askPermission: askPermission);
        if (!current(ticket, user)) return;
        if (token == null) {
          if (askPermission) error = 'Allow notifications in your phone settings to receive booking updates.';
          emit();
          return;
        }
        final old = deviceId;
        final id = await repository.registerBookingDevice(
          token,
          defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
        );
        if (!current(ticket, user)) {
          await gateway.deleteToken();
          return;
        }
        deviceId = id;
        error = null;
        await store.store.write(key(user!), '$id');
        await store.store.write(
          'bthere.customer.push.binding.v1',
          '${store.apiScope}|$user',
        );
        if (old != null && old != id) await repository.removeBookingDevice(old);
        emit();
      } catch (failure) {
        if (current(ticket, user)) {
          error = 'Notifications could not be registered. Please retry.';
          emit();
          await recoverAuth(failure);
        }
      }
    });
    registration = operation;
    return operation;
  }

  Future<void> unregister() async {
    signingOut = true;
    try {
      await registration.timeout(const Duration(seconds: 8));
      final user = owner, id = deviceId;
      if (user != null && id != null && auth.user?.id == user) {
        await repository
            .removeBookingDevice(id)
            .timeout(const Duration(seconds: 8));
        await store.store.delete(key(user));
        await store.store.delete('bthere.customer.push.binding.v1');
      }
    } catch (_) {
      /* Token revocation below is the fallback when offline. */
    } finally {
      await gateway
          .deleteToken()
          .timeout(const Duration(seconds: 8))
          .catchError((_) {});
      deviceId = null;
    }
  }

  Future<void> handle(BookingPush push) async {
    final ticket = epoch, user = owner;
    final event = int.tryParse('${push.data['eventId']}'),
        request = int.tryParse('${push.data['requestId']}');
    if (event != null && inFlight.contains(event) && push.opened) {
      pendingOpen.add(event);
    }
    if (!current(ticket, user) ||
        event == null ||
        event <= 0 ||
        request == null ||
        request <= 0 ||
        push.data['type'] is! String ||
        inFlight.contains(event) ||
        (push.opened ? opened.contains(event) : seen.contains(event))) {
      return;
    }
    inFlight.add(event);
    try {
      final view = await repository.readRequest(request);
      if (!current(ticket, user)) return;
      if (view['requestId'] != request ||
          view['userId'] != null && view['userId'] != user) {
        return;
      }
      final job = view['jobId'];
      final payable = {
        'AWAITING_CUSTOMER_CONFIRMATION',
        'PAYMENT_PENDING',
        'PAYMENT_RECONCILIATION',
      }.contains(view['status']);
      final chat =
          push.data['type'] == 'CHAT_MESSAGE_FROM_PROVIDER' &&
          job is int &&
          job > 0 &&
          int.tryParse('${push.data['jobId']}') == job;
      final path = chat
          ? '/messages/$job'
          : payable
          ? '/booking-requests/$request/payment'
          : job is int && job > 0
          ? '/bookings/$job'
          : '/opportunities';
      final wasOpened = push.opened || pendingOpen.remove(event);
      seen.add(event);
      if (wasOpened) opened.add(event);
      if (seen.length > 200) seen.remove(seen.first);
      if (opened.length > 200) opened.remove(opened.first);
      onRefresh();
      notice = BookingNotice(event, request, path, wasOpened, chat: chat);
      emit();
    } catch (failure) {
      /* Notification payload is a hint, not proof of an owned booking. */
      if (current(ticket, user)) await recoverAuth(failure);
    } finally {
      inFlight.remove(event);
      pendingOpen.remove(event);
    }
  }

  void clearNotice() {
    notice = null;
  }

  Future<void> recoverAuth(Object failure) async {
    if (failure is CustomerAuthFailure && failure.status == 401 && !auth.busy) {
      await auth.restore();
    }
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    auth.removeListener(identityChanged);
    if (auth.beforeLogout == logoutHook) auth.beforeLogout = null;
    for (final sub in subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
