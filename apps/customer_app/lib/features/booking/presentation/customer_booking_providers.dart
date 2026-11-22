import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/customer_theme.dart';
import 'booking_details_skeleton.dart';
import 'assigned_provider_details_sheet.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../../messages/presentation/customer_messages_screen.dart';
import '../../messages/data/customer_chat_repository.dart';

final customerProviderCallLauncherProvider =
    Provider<Future<bool> Function(Uri)>(
      (ref) =>
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );

class CustomerBookingProviders extends ConsumerStatefulWidget {
  const CustomerBookingProviders({
    super.key,
    required this.jobId,
    required this.status,
  });
  final int jobId;
  final String status;
  @override
  ConsumerState<CustomerBookingProviders> createState() =>
      _CustomerBookingProvidersState();
}

class _CustomerBookingProvidersState
    extends ConsumerState<CustomerBookingProviders>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>>? providers;
  bool loading = true;
  bool chatAvailable = false;
  Timer? chatExpiry;
  String? error;
  int epoch = 0;
  late final int? owner;
  bool get alive =>
      mounted &&
      owner != null &&
      ref.read(customerAuthControllerProvider).user?.id == owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;

  @override
  void initState() {
    super.initState();
    owner = ref.read(customerAuthControllerProvider).user?.id;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didUpdateWidget(CustomerBookingProviders oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.jobId != widget.jobId) {
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      load();
    }
  }

  Future<void> load() async {
    final ticket = ++epoch;
    chatExpiry?.cancel();
    chatAvailable = false;
    if (!alive) return;
    setState(() {
      loading = true;
      providers = null;
      error = null;
    });
    unawaited(_checkChat(ticket));
    try {
      final result = await ref
          .read(customerBookingRepositoryProvider)
          .bookingProviders(widget.jobId);
      if (alive && ticket == epoch) setState(() => providers = result);
    } catch (_) {
      if (alive && ticket == epoch) {
        setState(() => error = 'Provider details could not be loaded.');
      }
    } finally {
      if (alive && ticket == epoch) setState(() => loading = false);
    }
  }

  Future<void> _checkChat(int ticket) async {
    if (!{
      'CONFIRMED',
      'IN_PROGRESS',
      'AWAITING_COMPLETION_CONFIRMATION',
      'NO_SHOW_REVIEW',
      'COMPLETED',
      'CANCELLED',
    }.contains(widget.status)) {
      return;
    }
    final repository = ref.read(customerChatRepositoryProvider);
    try {
      final page = await repository.page(widget.jobId);
      if (!alive || ticket != epoch) return;
      final deadline = DateTime.tryParse('${page.data['sendUntil']}');
      final available =
          page.data['canSend'] == true &&
          (deadline == null || deadline.isAfter(repository.now()));
      setState(() => chatAvailable = available);
      if (available && deadline != null) {
        chatExpiry = Timer(deadline.difference(repository.now()), () {
          if (alive && ticket == epoch) setState(() => chatAvailable = false);
        });
      }
    } catch (_) {
      // Fail closed without hiding other provider details or marking chat read.
      if (alive && ticket == epoch) setState(() => chatAvailable = false);
    }
  }

  bool allowed(Map<String, dynamic> provider) =>
      alive &&
      !loading &&
      {'CONFIRMED', 'IN_PROGRESS'}.contains(widget.status) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (provider['contact'] as Map)['callAllowed'] == true;

  Future<void> call(Map<String, dynamic> provider) async {
    if (!allowed(provider)) return;
    final contact = provider['contact'] as Map;
    final phone = contact['phoneNumber'] ?? provider['phoneNumber'];
    if (phone is! String || !RegExp(r'^\+?[0-9 ()-]{3,30}$').hasMatch(phone)) {
      return;
    }
    try {
      final opened = await ref.read(customerProviderCallLauncherProvider)(
        Uri(scheme: 'tel', path: phone),
      );
      if (!opened) throw StateError('Dialler unavailable');
    } catch (_) {
      if (mounted && alive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the phone app.')),
        );
      }
    }
  }

  @override
  void dispose() {
    epoch++;
    chatExpiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!alive) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('booking-assigned-providers'),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CustomerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading) const BookingDetailsSkeleton(),
          if (error != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Text(error!, style: CustomerTypography.compact),
            ),
            TextButton(
              onPressed: load,
              child: const Text('Retry provider details'),
            ),
          ],
          if (!loading && error == null && providers?.isEmpty == true)
            const Text(
              'Provider details are not available yet.',
              style: CustomerTypography.compact,
            ),
          for (final provider in providers ?? <Map<String, dynamic>>[])
            _provider(provider),
        ],
      ),
    );
  }

  void _showDetails(Map<String, dynamic> provider) {
    if (!alive || loading) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAFCFD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AssignedProviderDetailsSheet(
        provider: provider,
        owner: owner!,
        jobId: widget.jobId,
        status: widget.status,
        onCall: () => call(provider),
      ),
    );
  }

  Widget _provider(Map<String, dynamic> provider) {
    final contact = provider['contact'] as Map;
    final phone = contact['phoneNumber'] ?? provider['phoneNumber'];
    final canCall =
        allowed(provider) && phone is String && phone.trim().isNotEmpty;
    final photo = provider['profilePhoto'];
    final photoUri = photo is String ? Uri.tryParse(photo) : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(provider),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: CustomerColors.selection,
                child:
                    photoUri != null &&
                        {'https', 'http'}.contains(photoUri.scheme)
                    ? ClipOval(
                        child: Image.network(
                          photo as String,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_outline,
                            color: CustomerColors.action,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_outline,
                        color: CustomerColors.action,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['role'] == 'TEAM_MEMBER'
                          ? 'Team member'
                          : 'Provider',
                      style: CustomerTypography.compactStrong.copyWith(
                        color: CustomerColors.secondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider['displayName'] as String,
                      style: CustomerTypography.card.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canCall)
                      Text(
                        phone,
                        style: CustomerTypography.card.copyWith(
                          color: CustomerColors.secondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      Text(switch (contact['unavailableReason']) {
                        'BOOKING_NOT_CONFIRMED' =>
                          'Contact available after payment.',
                        'BOOKING_ENDED' => 'Contact unavailable after service.',
                        _ => 'Phone not available.',
                      }, style: CustomerTypography.compact),
                  ],
                ),
              ),
              if (canCall) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Call provider',
                  style: IconButton.styleFrom(
                    backgroundColor: CustomerColors.selection,
                    foregroundColor: CustomerColors.action,
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => call(provider),
                  icon: const Icon(Icons.call_outlined, size: 26),
                ),
              ],
              if (chatAvailable) ...[
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: ValueKey(
                    'booking-provider-chat-${provider['providerId']}',
                  ),
                  tooltip: 'Message provider',
                  style: IconButton.styleFrom(
                    backgroundColor: CustomerColors.selection,
                    foregroundColor: CustomerColors.action,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => showBookingChatSheet(
                    context,
                    widget.jobId,
                    participant: provider,
                    onAvailabilityChanged: (available) {
                      if (alive && chatAvailable != available) {
                        setState(() => chatAvailable = available);
                      }
                    },
                    onCall: canCall ? () => call(provider) : null,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
