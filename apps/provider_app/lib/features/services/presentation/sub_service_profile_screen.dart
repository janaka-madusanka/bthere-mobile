import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../application/service_detail_controller.dart';
import '../data/registration_repository.dart';
import '../documents/documents_controller.dart';
import 'registration_option_editor.dart';
import 'registration_option_summary.dart';
import 'registration_widgets.dart';

class SubServiceProfileScreen extends ConsumerStatefulWidget {
  const SubServiceProfileScreen({
    required this.serviceTypeId,
    required this.optionId,
    super.key,
  });
  final int serviceTypeId, optionId;
  @override
  ConsumerState<SubServiceProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<SubServiceProfileScreen> {
  Map<String, dynamic>? data, location;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref.read(
        serviceDetailControllerProvider(widget.serviceTypeId).future,
      );
      if (result is! Success<ServiceDetailState>) {
        throw StateError('Unavailable');
      }
      final v = result.value;
      final registered = v.registered
          .where((o) => o.optionId == widget.optionId)
          .firstOrNull;
      if (registered == null ||
          registered.verificationStatus != 'APPROVED' ||
          registered.providerStatus == 'INACTIVE' ||
          registered.adminStatus == 'INACTIVE') {
        if (mounted) context.go('/services/${widget.serviceTypeId}');
        return;
      }
      final option = v.schema.options.firstWhere(
        (o) => o.optionId == widget.optionId,
      );
      final repository = ref.read(registrationRepositoryProvider);
      final snapshot = await repository.load(
        v.assignment!.assignmentId,
        v.schema.serviceSetup,
      );
      final areas = v.schema.serviceSetup.serviceAreasEnabled
          ? await repository.loadOptionLocations(v.assignment!.assignmentId, [
              option,
            ])
          : const Success<Map<String, dynamic>>({});
      if (snapshot is! Success<Map<String, dynamic>> ||
          areas is! Success<Map<String, dynamic>>) {
        throw StateError('Unavailable');
      }
      if (!mounted) return;
      setState(() {
        data = snapshot.value;
        location = Map<String, dynamic>.from(
          areas.value['${widget.optionId}'] as Map? ?? {},
        );
      });
      await ref
          .read(documentsControllerProvider(widget.serviceTypeId).notifier)
          .load();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'Unable to load this sub-service profile. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit(ServiceDetailState v, ProviderSchemaOption option) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          var saving = false;
          String? saveError;
          return StatefulBuilder(
            builder: (context, update) => RegistrationOptionEditor(
              option: ProviderSchemaOption(
                optionId: option.optionId,
                code: option.code,
                name: option.name,
                fields: [],
                deliveryModes: option.deliveryModes,
                icon: option.icon,
              ),
              service: v.service,
              setup: v.schema.serviceSetup,
              assignmentId: v.assignment!.assignmentId,
              initial: {
                ...?location,
                'availability': data?['availability'] ?? {},
              },
              busy: saving,
              saveError: saveError,
              onSave: (changes) async {
                if (saving) return;
                update(() {
                  saving = true;
                  saveError = null;
                });
                try {
                  final repository = ref.read(registrationRepositoryProvider);
                  if (v.schema.serviceSetup.availabilityEnabled) {
                    final result = await repository.availability(
                      v.assignment!.assignmentId,
                      Map<String, dynamic>.from(changes['availability'] as Map),
                    );
                    if (result is Failure<void>) {
                      throw StateError(result.failure.message);
                    }
                  }
                  final mode = changes['deliveryMode'];
                  if (v.schema.serviceSetup.serviceAreasEnabled &&
                      RegistrationRepository.physicalModes.contains(mode)) {
                    final result = await repository.saveAreas(
                      v.assignment!.assignmentId,
                      option.optionId,
                      mode as String,
                      (changes['areas'] as List)
                          .map((a) => Map<String, dynamic>.from(a as Map))
                          .toList(),
                    );
                    if (result is Failure<void>) {
                      throw StateError(result.failure.message);
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted) {
                    update(() {
                      saving = false;
                      saveError = 'Unable to save changes. Please retry.';
                    });
                  }
                }
              },
            ),
          );
        },
      ),
    );
    if (mounted) await load();
  }

  Widget badge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFDCF9F3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: registrationText(label, 10, color: registrationTeal),
  );
  Widget symbol(IconData icon) => CircleAvatar(
    radius: 21,
    backgroundColor: const Color(0xFFE4F9F7),
    child: Icon(icon, color: const Color(0xFF009FA4), size: 23),
  );
  Widget section(
    String title,
    String subtitle,
    IconData icon,
    Widget child,
    VoidCallback onTap, {
    String action = 'View All',
  }) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFEDF0F6)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            symbol(icon),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  registrationText(title, 14, bold: true),
                  registrationText(subtitle, 10, color: registrationMuted),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE8F6FF),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 28),
              ),
              child: Text(
                action,
                style: const TextStyle(fontSize: 10, color: Color(0xFF159CF0)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
  void view(String title, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              registrationText(title, 20, bold: true),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = ref
        .watch(serviceDetailControllerProvider(widget.serviceTypeId))
        .asData
        ?.value;
    final documents = ref.watch(
      documentsControllerProvider(widget.serviceTypeId),
    );
    Widget content = const Center(child: CircularProgressIndicator());
    if (!loading && error != null) {
      content = Column(
        children: [
          Text(error!),
          TextButton(onPressed: load, child: const Text('Retry')),
        ],
      );
    } else if (!loading &&
        result is Success<ServiceDetailState> &&
        data != null) {
      final v = result.value;
      final option = v.schema.options
          .where((o) => o.optionId == widget.optionId)
          .firstOrNull;
      if (option != null) {
        final availability = data!['availability'] as Map? ?? {};
        final slots = (availability['weeklySlots'] as List? ?? [])
            .whereType<Map>();
        final days = availability['availableAnyDay'] == true
            ? 'Every day'
            : slots.map((s) => s['dayOfWeek']).join(', ');
        final times = availability['availableAnyTime'] == true
            ? 'Any time'
            : slots
                  .map((s) => '${s['startTime']} – ${s['endTime']}')
                  .toSet()
                  .join(', ');
        final areas = (location?['areas'] as List? ?? []).whereType<Map>();
        final overview = Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: RegistrationOptionArtwork(option: option),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          registrationText(option.name, 15, bold: true),
                          badge('• Active'),
                        ],
                      ),
                      if (option.description != null)
                        registrationText(
                          option.description!,
                          11,
                          color: registrationMuted,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in [
                  (
                    'Experience',
                    v.experience.isEmpty ? 'Not provided' : v.experience,
                  ),
                  ('Languages', (data!['languages'] as List? ?? []).join(', ')),
                  (
                    'Skills',
                    '${(data!['skills'] as List? ?? []).length} skills',
                  ),
                ])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        registrationText(item.$1, 9, color: registrationMuted),
                        registrationText(item.$2, 10, bold: true),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
        final qualifications = Column(
          children: [
            for (final requirement in documents.requirements ?? [])
              if (requirement.optionId == null ||
                  requirement.optionId == widget.optionId)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: symbol(Icons.description_outlined),
                  title: registrationText(requirement.name, 11, bold: true),
                  subtitle: registrationText(
                    documents.documents
                            ?.where((d) => d.typeId == requirement.id)
                            .firstOrNull
                            ?.name ??
                        'Not provided',
                    10,
                    color: registrationMuted,
                  ),
                  trailing: badge(
                    documents.documents
                            ?.where((d) => d.typeId == requirement.id)
                            .firstOrNull
                            ?.status(DateTime.now()) ??
                        'Not provided',
                  ),
                ),
            for (final kind in ['certificates', 'education'])
              for (final entry in (data![kind] as List? ?? []).whereType<Map>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: symbol(
                    kind == 'education'
                        ? Icons.school_outlined
                        : Icons.workspace_premium_outlined,
                  ),
                  title: registrationText(
                    (entry['name'] ??
                            entry['title'] ??
                            entry['certificateName'] ??
                            entry['qualification'] ??
                            kind)
                        .toString(),
                    11,
                    bold: true,
                  ),
                  subtitle: registrationText(
                    (entry['institution'] ?? entry['institutionName'] ?? '')
                        .toString(),
                    10,
                    color: registrationMuted,
                  ),
                  trailing: badge(
                    (entry['verificationStatus'] ?? 'Status unavailable')
                        .toString(),
                  ),
                ),
            if (documents.requirementsError != null ||
                documents.documentsError != null)
              TextButton(onPressed: load, child: const Text('Retry documents')),
          ],
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9FBF8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 85,
                    height: 85,
                    child: RegistrationAsset('complete_imgApprovedCheck'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        badge('\u2713 Service Approved'),
                        const SizedBox(height: 5),
                        registrationText(
                          'Your ${option.name} Service is Active!',
                          16,
                          bold: true,
                        ),
                        registrationText(
                          'You can now start receiving booking requests based on your availability and service areas.',
                          11,
                          color: registrationMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            section(
              'Service Details',
              "Here's the information you submitted for this service.",
              Icons.work_outline,
              overview,
              () => view('Service Details', overview),
            ),
            section(
              'Documents & Qualifications',
              'The documents and qualifications you submitted.',
              Icons.description_outlined,
              Column(
                children: [
                  qualifications,
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock,
                          color: registrationTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: registrationText(
                            'These documents cannot be edited.\nIf you need to update any document, please contact support.',
                            10,
                            color: registrationMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              () => view('Documents & Qualifications', qualifications),
            ),
            if (v.schema.serviceSetup.availabilityEnabled)
              section(
                'Availability',
                'Manage the days and times you are available for bookings.',
                Icons.calendar_month,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: symbol(Icons.calendar_month),
                  title: registrationText('Available on', 11, bold: true),
                  subtitle: registrationText(
                    '$days\n$times',
                    11,
                    color: registrationMuted,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: registrationMuted,
                  ),
                  onTap: () => edit(v, option),
                ),
                () => edit(v, option),
                action: '\u270E Edit',
              ),
            if (v.schema.serviceSetup.serviceAreasEnabled)
              section(
                'Working Areas',
                'Manage the areas where you provide services.',
                Icons.location_on,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: symbol(Icons.location_on_outlined),
                  title: registrationText('Service Areas', 11, bold: true),
                  subtitle: registrationText(
                    areas.isEmpty
                        ? (location?['deliveryMode'] == 'ONLINE'
                              ? 'Online'
                              : 'Not provided')
                        : areas
                              .map((a) => a['locationName'] ?? a['city'] ?? '')
                              .join(', '),
                    11,
                    color: registrationMuted,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: registrationMuted,
                  ),
                  onTap: () => edit(v, option),
                ),
                () => edit(v, option),
                action: '\u270E Edit',
              ),
          ],
        );
      }
    }
    return RegistrationPage(
      step: 1,
      title: 'Service Profile',
      showProgress: false,
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/services/${widget.serviceTypeId}');
        }
      },
      child: content,
    );
  }
}
