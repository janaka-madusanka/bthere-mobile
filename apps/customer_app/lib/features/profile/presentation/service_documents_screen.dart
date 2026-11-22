import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../booking/application/customer_booking_controller.dart';
import '../../booking/domain/booking_models.dart';
import '../../discovery/application/customer_discovery_controller.dart';
import 'profile_document_sheet.dart';

Map<String, dynamic> scopedDocument(CustomerRequirement r, BookingKey key) => {
  'requirementId': r.field.id,
  'name': r.field.label,
  'fieldType': r.field.type,
  'status': r.status,
  'services': [
    {'serviceTypeId': key.serviceId, 'optionId': key.optionId},
  ],
};

class ServiceDocumentRequirements extends StatelessWidget {
  const ServiceDocumentRequirements({
    super.key,
    required this.requirements,
    required this.bookingKey,
    required this.busy,
    required this.onRefresh,
    required this.onOpen,
    this.error,
    this.eligible = false,
  });
  final List<CustomerRequirement> requirements;
  final BookingKey bookingKey;
  final bool busy, eligible;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<CustomerRequirement> onOpen;

  @override
  Widget build(BuildContext context) {
    final documents = requirements.where((r) => r.field.upload).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CustomerColors.selection,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: CustomerColors.action,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      eligible
                          ? 'Documents ready'
                          : 'Documents needed before booking',
                      style: CustomerTypography.card.copyWith(
                        color: const Color(0xFF10143F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Submit the documents required for this service. Documents that need review must be approved before you can book.',
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (documents.isEmpty && !busy && error == null)
          const Text(
            'No additional documents are required for this service.',
            style: CustomerTypography.body,
          ),
        for (final r in documents)
          Container(
            key: ValueKey('service-document-${r.field.id}'),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CustomerColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: CustomerColors.selection,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        size: 22,
                        color: CustomerColors.action,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.field.label,
                        style: CustomerTypography.card.copyWith(
                          color: const Color(0xFF10143F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: {'REJECTED', 'EXPIRED'}.contains(r.status)
                          ? const Color(0xFFFFEDF0)
                          : r.status == 'PENDING'
                          ? const Color(0xFFFFF4DF)
                          : const Color(0xFFE9F8F2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      switch (r.status) {
                        'MISSING' => 'Not submitted',
                        'PENDING' => 'Under review',
                        'APPROVED' => 'Approved',
                        'PROVIDED' => 'Submitted',
                        'REJECTED' => 'Rejected - please resubmit',
                        'EXPIRED' => 'Expired - please resubmit',
                        _ => r.status,
                      },
                      style: CustomerTypography.compactStrong.copyWith(
                        color: {'REJECTED', 'EXPIRED'}.contains(r.status)
                            ? CustomerColors.error
                            : r.status == 'PENDING'
                            ? const Color(0xFF9B6810)
                            : CustomerColors.action,
                      ),
                    ),
                  ),
                ),
                if (r.field.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    r.field.description!,
                    style: CustomerTypography.compact.copyWith(
                      color: CustomerColors.secondaryText,
                    ),
                  ),
                ],
                if (r.rejection?.isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: CustomerColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.rejection!,
                            style: CustomerTypography.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (r.expires != null)
                  Text(
                    'Expiry: ${r.expires}',
                    style: CustomerTypography.compact,
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: CustomerColors.action,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r.field.minFiles}-${r.field.maxFiles ?? "many"} files, up to ${r.field.maxMb} MB each',
                          style: CustomerTypography.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.field.fileTypes.isNotEmpty)
                  Text(
                    r.field.fileTypes.join(', '),
                    style: CustomerTypography.compact,
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: CustomerColors.selection,
                    foregroundColor: CustomerColors.action,
                    side: const BorderSide(color: Color(0xFFB6E3DF)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: busy ? null : () => onOpen(r),
                  child: Text(
                    {'MISSING', 'REJECTED', 'EXPIRED'}.contains(r.status)
                        ? 'Upload / resubmit'
                        : 'View documents',
                  ),
                ),
              ],
            ),
          ),
        if (!eligible &&
            requirements.any(
              (r) =>
                  !r.field.upload &&
                  r.blocksBooking &&
                  !{'APPROVED', 'PROVIDED'}.contains(r.status),
            ))
          const Text(
            'Other information is also required. Complete it in the booking form after your documents are ready.',
            style: CustomerTypography.compact,
          ),
        if (error != null)
          Text(
            error!,
            style: CustomerTypography.body.copyWith(
              color: CustomerColors.error,
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: busy ? null : onRefresh,
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  busy ? 'Checking...' : 'Check review status',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ServiceDocumentsScreen extends ConsumerStatefulWidget {
  const ServiceDocumentsScreen({super.key});
  @override
  ConsumerState<ServiceDocumentsScreen> createState() =>
      _ServiceDocumentsScreenState();
}

class _ServiceDocumentsScreenState
    extends ConsumerState<ServiceDocumentsScreen> {
  late final int? owner;
  int? market, service, option;
  List<CustomerRequirement> requirements = [];
  bool busy = false, eligible = false;
  int epoch = 0;
  String? error;
  bool get alive =>
      mounted &&
      ref.read(customerAuthControllerProvider).user?.id == owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;
  @override
  void initState() {
    super.initState();
    owner = ref.read(customerAuthControllerProvider).user?.id;
    final catalog = ref.read(customerDiscoveryProvider);
    market = catalog.activeMarket?.id;
    Future.microtask(() {
      if (alive && catalog.services.isEmpty) catalog.loadServices();
    });
  }

  Future<void> load() async {
    if (!alive || market == null || service == null || option == null) return;
    final ticket = ++epoch;
    final key = BookingKey(market!, service!, option!);
    setState(() {
      busy = true;
      error = null;
      eligible = false;
    });
    try {
      final repo = ref.read(customerBookingRepositoryProvider);
      final result = await Future.wait<Object>([
        repo.requirements(key),
        repo.eligibility(key),
      ]);
      if (alive && ticket == epoch) {
        setState(() {
          requirements = result[0] as List<CustomerRequirement>;
          eligible = (result[1] as Map)['eligible'] == true;
        });
      }
    } catch (_) {
      if (alive && ticket == epoch) {
        setState(
          () => error = 'Unable to load service documents. Please retry.',
        );
      }
    } finally {
      if (mounted && ticket == epoch) setState(() => busy = false);
    }
  }

  Future<void> open(CustomerRequirement r) async {
    if (!alive || busy) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => ProfileDocumentSheet(
        owner: owner!,
        document: scopedDocument(r, BookingKey(market!, service!, option!)),
      ),
    );
    if (alive) await load();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(customerDiscoveryProvider);
    ref.watch(customerAuthControllerProvider);
    if (!alive) return const SizedBox.shrink();
    final options = service == null ? null : catalog.optionsFor(service!);
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: CustomerColors.action,
          foregroundColor: Colors.white,
          title: Text(
            'Add service documents',
            style: CustomerTypography.section.copyWith(color: Colors.white),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose a service', style: CustomerTypography.section),
              const SizedBox(height: 8),
              const Text(
                'You can submit service documents before starting a booking.',
                style: CustomerTypography.body,
              ),
              const SizedBox(height: 16),
              if (market == null || market != catalog.activeMarket?.id) ...[
                const Text(
                  'Choose your service area to see available services.',
                ),
                TextButton(
                  onPressed: () => context.go('/market'),
                  child: const Text('Choose service area'),
                ),
              ] else ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('profile-document-service'),
                  initialValue: service,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: catalog.services
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (id) {
                          epoch++;
                          setState(() {
                            service = id;
                            option = null;
                            requirements = [];
                            error = null;
                          });
                          if (id != null) catalog.loadOptions(id);
                        },
                ),
                if (catalog.serviceError != null)
                  TextButton(
                    onPressed: catalog.loadServices,
                    child: const Text('Retry services'),
                  ),
                const SizedBox(height: 14),
                if (service != null)
                  DropdownButtonFormField<int>(
                    key: ValueKey('profile-document-option-$service'),
                    initialValue: option,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Service option',
                    ),
                    items: (options?.options ?? [])
                        .map(
                          (o) => DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (id) {
                            epoch++;
                            setState(() {
                              option = id;
                              requirements = [];
                            });
                            load();
                          },
                  ),
                if (service != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => catalog.loadOptions(service!, retry: true),
                    child: const Text('Refresh service options'),
                  ),
                const SizedBox(height: 16),
                if (busy) const LinearProgressIndicator(),
                if (option != null)
                  ServiceDocumentRequirements(
                    requirements: requirements,
                    bookingKey: BookingKey(market!, service!, option!),
                    busy: busy,
                    eligible: eligible,
                    error: error,
                    onRefresh: load,
                    onOpen: open,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
