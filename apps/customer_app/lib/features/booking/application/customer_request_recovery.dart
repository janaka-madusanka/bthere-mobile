import 'package:flutter/foundation.dart';

import '../../wallet/application/customer_wallet_controller.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/customer_auth_controller.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import '../../discovery/data/customer_market_selection_store.dart';
import '../data/customer_booking_repository.dart';
import '../data/customer_request_recovery_store.dart';
import 'customer_booking_controller.dart';
import 'customer_booking_history.dart';
import '../../messages/application/customer_chat_controller.dart';

final customerRequestRecoveryProvider =
    Provider.autoDispose<CustomerRequestRecovery>(
      (ref) {
        final auth = ref.watch(customerAuthControllerProvider);
        final recovery = CustomerRequestRecovery(
          ref.watch(customerBookingRepositoryProvider),
          auth,
          ref.watch(customerMarketSelectionStoreProvider),
          onChange: () {
            final owner = auth.user?.id;
            if (owner != null) {
              ref.invalidate(customerBookingHistoryProvider(owner));
            }
          },
          onChat: () => ref.read(customerChatInboxProvider)?.refresh(),
          onAutoCancel: () => ref.invalidate(customerWalletProvider),
        );
        ref.onDispose(recovery.dispose);
        return recovery;
      },
      dependencies: [
        customerAuthControllerProvider,
        customerBookingRepositoryProvider,
        customerMarketSelectionStoreProvider,
        customerChatInboxProvider,
        customerWalletProvider,
      ],
    );

class CustomerRequestRecovery extends ChangeNotifier {
  CustomerRequestRecovery(
    this.repository,
    this.auth,
    this.selection, {
    this.onChange,
    this.onChat,
    this.onAutoCancel,
  }) {
    auth.addListener(_identityChanged);
  }
  final CustomerBookingRepository repository;
  final CustomerAuthController auth;
  final CustomerMarketSelectionStore selection;
  final VoidCallback? onChange;
  final VoidCallback? onChat;
  final VoidCallback? onAutoCancel;
  final requests = <int, Map<String, dynamic>>{};
  final _knownIds = <int>{};
  bool loading = false, _disposed = false;
  String? error;
  int? _owner;
  int _after = 0, _epoch = 0;
  final _jobReads = <int>{};
  void _identityChanged() {
    if (_owner != auth.user?.id ||
        auth.stage != CustomerAuthStage.authenticated) {
      _epoch++;
      _owner = null;
      _after = 0;
      requests.clear();
      _knownIds.clear();
      _jobReads.clear();
      loading = false;
      error = null;
      if (!_disposed) notifyListeners();
    }
  }

  bool current(int owner, int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      auth.user?.id == owner &&
      auth.stage == CustomerAuthStage.authenticated;
  Future<void> remember(int id) async {
    final owner = auth.user?.id;
    if (owner == null) return;
    _knownIds.add(id);
    await CustomerRequestRecoveryStore(selection, owner).remember(id);
  }

  Future<Map<String, dynamic>> _readRequest(int id) async {
    final row = await repository.readRequest(id);
    if (row['requestId'] != id) {
      throw const FormatException('Invalid request identity');
    }
    if (!{
      'AWAITING_CUSTOMER_CONFIRMATION',
      'PAYMENT_PENDING',
      'PAYMENT_RECONCILIATION',
    }.contains(row['status'])) {
      return row;
    }
    try {
      final actions = await repository.paymentWindow(id);
      if (actions['status'] == row['status'] &&
          actions['paymentStatus'] == row['paymentStatus']) {
        // Window metadata must not erase the View's owned job/provider link.
        return {
          ...row,
          for (final key in [
            'canPay',
            'canCancel',
            'confirmationExpiresAt',
            'paymentRetryStartedAt',
          ])
            key: actions[key],
        };
      }
    } catch (_) {}
    return {...row, 'canPay': false, 'canCancel': false};
  }

  void _publish(int id, Map<String, dynamic> row) {
    final previous = requests[id];
    requests[id] = row;
    if (previous?['status'] != row['status'] ||
        previous?['paymentStatus'] != row['paymentStatus'] ||
        previous?['jobId'] != row['jobId']) {
      onChange?.call();
    }
    notifyListeners();
  }

  /// A details screen must not wait for the entire account's event/history scan.
  /// Stored links are hints only: the owned request View must match the job.
  Future<void> refreshJob(int jobId, {int? requestId}) async {
    final owner = auth.user?.id;
    if (_disposed ||
        owner == null ||
        auth.stage != CustomerAuthStage.authenticated ||
        !_jobReads.add(jobId)) {
      return;
    }
    _owner = owner;
    final epoch = _epoch;
    final store = CustomerRequestRecoveryStore(selection, owner);
    try {
      int? saved;
      try {
        saved = await store.requestForJob(jobId);
      } catch (_) {}
      if (!current(owner, epoch)) return;
      final known = requests.entries
          .where((e) => e.value['jobId'] == jobId)
          .firstOrNull
          ?.key;
      final preferred = [
        requestId,
        known,
        saved,
      ].whereType<int>().where((id) => id > 0).toSet();
      final ids = <int>{..._knownIds};
      try {
        ids.addAll(await store.read());
      } catch (_) {}
      if (!current(owner, epoch)) return;
      final newest = ids.toList()..sort((a, b) => b.compareTo(a));
      for (final id in {...preferred, ...newest}) {
        try {
          final row = await _readRequest(id);
          if (!current(owner, epoch)) return;
          if (row['jobId'] != jobId) continue;
          _knownIds.add(id);
          final previous = requests[id];
          final unchanged =
              previous?['status'] == row['status'] &&
              previous?['paymentStatus'] == row['paymentStatus'];
          _publish(id, row);
          // The request may already be funded while a cached job list still
          // says awaiting payment. Re-read that list until it catches up.
          if (unchanged &&
              {
                'CONFIRMED',
                'IN_PROGRESS',
                'AWAITING_COMPLETION_CONFIRMATION',
                'COMPLETED',
                'CANCELLED',
                'EXPIRED',
              }.contains(row['status'])) {
            onChange?.call();
          }
          try {
            await store.remember(id);
            await store.saveJobRequest(jobId, id);
          } catch (_) {}
          return;
        } catch (_) {
          if (!current(owner, epoch)) return;
        }
      }
      // New devices can still recover the reference through owned events.
      await refresh();
    } finally {
      if (current(owner, epoch)) _jobReads.remove(jobId);
    }
  }

  Future<void> refresh() async {
    final owner = auth.user?.id;
    if (_disposed ||
        loading ||
        owner == null ||
        auth.stage != CustomerAuthStage.authenticated) {
      return;
    }
    _owner = owner;
    final epoch = _epoch;
    loading = true;
    notifyListeners();
    final store = CustomerRequestRecoveryStore(selection, owner);
    try {
      // Local persistence must never prevent server-side event recovery.
      final ids = {..._knownIds};
      var referencesReadable = true;
      try {
        ids.addAll(await store.read());
      } catch (_) {
        referencesReadable = false;
        _after = 0;
      }
      if (_after == 0 && referencesReadable) {
        var cursor = 0;
        try {
          cursor = await store.cursor();
        } catch (_) {}
        if (!current(owner, epoch)) return;
        _after = cursor;
      }
      final changed = <int>{};
      var eventFailure = false;
      // Events recover references after process death, missed push or a second device.
      // Do not assume event payloads contain prices, job or service metadata.
      try {
        for (var page = 0; page < 10; page++) {
          final events = await repository.events(_after);
          if (!current(owner, epoch)) return;
          if (events.any(
            (e) =>
                e['type'] == 'CHAT_MESSAGE_FROM_PROVIDER' ||
                e['eventType'] == 'CHAT_MESSAGE_FROM_PROVIDER',
          )) {
            onChat?.call();
          }
          var next = _after;
          for (final event in events) {
            final eventId = event['eventId'], requestId = event['requestId'];
            if (eventId is! int ||
                eventId <= 0 ||
                requestId is! int ||
                requestId <= 0) {
              throw const FormatException('Invalid booking event');
            }
            if (event['userId'] != null && event['userId'] != owner) {
              throw const FormatException('Invalid event owner');
            }
            if ((event['eventType'] ?? event['type']) ==
                'BOOKING_AUTO_CANCELLED') {
              onAutoCancel?.call();
            }
            ids.add(requestId);
            _knownIds.add(requestId);
            changed.add(requestId);
            if (eventId > next) next = eventId;
          }
          // Persist references before the cursor, so process death cannot skip
          // events whose request IDs have not yet reached secure storage.
          var persisted = true;
          for (final id in ids) {
            try {
              await store.remember(id);
            } catch (_) {
              persisted = false;
            }
          }
          if (!current(owner, epoch)) return;
          if (next == _after) break;
          // Keep cursor unchanged when references cannot be saved. Server reads
          // can still render this session; restart replays the events safely.
          if (persisted) {
            try {
              await store.saveCursor(next);
            } catch (_) {
              persisted = false;
            }
          }
          if (!current(owner, epoch)) return;
          if (!persisted) break;
          _after = next;
          if (events.length < 100) break;
        }
      } catch (_) {
        eventFailure = true;
        // Device-known references still recover if event service is unavailable.
      }
      var failed = false;
      final newestIds = ids.toList()..sort((a, b) => b.compareTo(a));
      for (final id in newestIds) {
        if (!current(owner, epoch)) return;
        final cached = requests[id];
        if (cached != null &&
            {
              'CONFIRMED',
              'COMPLETED',
              'CANCELLED',
              'EXPIRED',
              'UNMATCHED',
            }.contains(cached['status']) &&
            !changed.contains(id)) {
          continue;
        }
        try {
          final row = await _readRequest(id);
          if (!current(owner, epoch)) return;
          _publish(id, row);
          if (row['jobId'] is int) {
            try {
              await store.saveJobRequest(row['jobId'] as int, id);
            } catch (_) {}
          }
        } catch (_) {
          failed = true;
        }
      }
      if (!current(owner, epoch)) return;
      // Results are published as they arrive, not after every old request has
      // finished. Do not overwrite a newer targeted read with the scan snapshot.
      error = eventFailure && ids.isEmpty
          ? 'Unable to check payment requests. Tap to retry.'
          : failed
          ? 'Some request statuses could not be updated. Open the request to check.'
          : null;
    } catch (_) {
      if (current(owner, epoch)) {
        error = 'Payment requests could not be loaded. Please retry.';
      }
    } finally {
      if (current(owner, epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  List<Map<String, dynamic>> get active =>
      requests.values
          .where(
            (r) => {
              'AWAITING_CUSTOMER_CONFIRMATION',
              'PAYMENT_PENDING',
              'PAYMENT_RECONCILIATION',
            }.contains(r['status']),
          )
          .toList()
        ..sort(
          (a, b) => (b['requestId'] as int).compareTo(a['requestId'] as int),
        );
  @override
  void dispose() {
    _disposed = true;
    auth.removeListener(_identityChanged);
    super.dispose();
  }
}
