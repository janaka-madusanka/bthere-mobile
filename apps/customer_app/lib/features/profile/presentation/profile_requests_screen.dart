import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../booking/application/customer_booking_controller.dart';
import '../data/customer_profile_overview_repository.dart';

Future<void> showProfileRequest(
  BuildContext context,
  WidgetRef ref,
  int id,
) async {
  final owner = ref.read(customerAuthControllerProvider).user?.id;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RequestStatus(id: id, owner: owner),
  );
}

class _RequestStatus extends ConsumerStatefulWidget {
  const _RequestStatus({required this.id, required this.owner});
  final int id;
  final int? owner;
  @override
  ConsumerState<_RequestStatus> createState() => _RequestStatusState();
}

class _RequestStatusState extends ConsumerState<_RequestStatus> {
  late Future<Map<String, dynamic>> request;
  @override
  void initState() {
    super.initState();
    request = ref
        .read(customerBookingRepositoryProvider)
        .readRequest(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(customerAuthControllerProvider).user?.id != widget.owner) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: FutureBuilder(
        future: request,
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request #${widget.id}', style: CustomerTypography.section),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              TextButton(
                onPressed: () => setState(
                  () => request = ref
                      .read(customerBookingRepositoryProvider)
                      .readRequest(widget.id),
                ),
                child: const Text('Retry request status'),
              ),
            if (snapshot.data case final Map<String, dynamic> row) ...[
              Text('${row['status']}', style: CustomerTypography.card),
              if (row['status'] == 'MATCHING')
                const Text(
                  'Finding an available provider for your request.',
                  style: CustomerTypography.body,
                ),
              if (row['jobId'] is int)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/bookings/${row['jobId']}');
                  },
                  child: const Text('View booking details'),
                ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileRequestsScreen extends ConsumerStatefulWidget {
  const ProfileRequestsScreen({super.key});
  @override
  ConsumerState<ProfileRequestsScreen> createState() =>
      _ProfileRequestsScreenState();
}

class _ProfileRequestsScreenState extends ConsumerState<ProfileRequestsScreen> {
  final rows = <Map<String, dynamic>>[];
  int page = 0;
  bool busy = false, more = true;
  String? error;
  late final int? owner;
  @override
  void initState() {
    super.initState();
    owner = ref.read(customerAuthControllerProvider).user?.id;
    load();
  }

  Future<void> load() async {
    if (busy || !more) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ref
          .read(customerProfileOverviewRepositoryProvider)
          .requests(page);
      if (!mounted ||
          ref.read(customerAuthControllerProvider).user?.id != owner) {
        return;
      }
      setState(() {
        rows.addAll(
          (data['items'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where(
                (r) => !{
                  'COMPLETED',
                  'CANCELLED',
                  'UNMATCHED',
                  'EXPIRED',
                  'PAYMENT_FAILED',
                }.contains(r['status']),
              )
              .where(
                (r) => !rows.any((old) => old['requestId'] == r['requestId']),
              ),
        );
        more = data['hasMore'] == true;
        page++;
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Requests could not be loaded.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alive = ref.watch(customerAuthControllerProvider).user?.id == owner;
    return Scaffold(
      appBar: AppBar(title: const Text('Pending requests')),
      body: !alive
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Bookings made without a request are available in Booking.',
                  style: CustomerTypography.compact,
                ),
                TextButton(
                  onPressed: () => context.push('/opportunities'),
                  child: const Text('View all bookings'),
                ),
                for (final row in rows)
                  ListTile(
                    title: Text(
                      row['optionName'] as String? ??
                          row['serviceName'] as String? ??
                          'Service request',
                    ),
                    subtitle: Text('${row['status']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => row['jobId'] is int
                        ? context.push('/bookings/${row['jobId']}')
                        : showProfileRequest(
                            context,
                            ref,
                            row['requestId'] as int,
                          ),
                  ),
                if (!busy && error == null && rows.isEmpty)
                  const Text('No pending requests.'),
                if (error != null) Text(error!),
                if (busy)
                  const Center(child: CircularProgressIndicator())
                else if (more)
                  TextButton(
                    onPressed: load,
                    child: Text(error == null ? 'Load more' : 'Retry requests'),
                  ),
              ],
            ),
    );
  }
}
