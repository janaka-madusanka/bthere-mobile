import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../application/registration_draft.dart';
import '../application/service_detail_controller.dart';
import '../application/service_providers.dart';
import 'registration_widgets.dart';
import 'registration_details.dart';
import 'registration_documents.dart';
import 'registration_review.dart';
import '../application/registration_payload.dart';
import '../data/registration_repository.dart';
import '../documents/documents_controller.dart';
import 'service_catalog_visuals.dart';
import '../../../app/providers/app_providers.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';

class ServiceRegistrationScreen extends ConsumerStatefulWidget {
  const ServiceRegistrationScreen({
    this.serviceTypeId,
    this.initialStep = 1,
    this.optionId,
    super.key,
  });
  final int? serviceTypeId;
  final int initialStep;
  final int? optionId;
  @override
  ConsumerState<ServiceRegistrationScreen> createState() =>
      _RegistrationState();
}

class _RegistrationState extends ConsumerState<ServiceRegistrationScreen> {
  int step = 1;
  int? selected;
  final Set<int> chosen = {}, submitted = {};
  bool busy = false;
  Map<String, dynamic> draft = {};
  String? error;
  ServiceDetailState? cached;
  bool approved = false;
  bool allApproved = true;
  @override
  void initState() {
    super.initState();
    selected = widget.serviceTypeId;
    if (selected != null) chosen.add(selected!);
    if (widget.initialStep != 1 && selected != null) {
      step = 2;
      Future.microtask(details);
    }
  }

  Future<ServiceDetailState> current() async {
    final result = await ref.read(
      serviceDetailControllerProvider(selected!).future,
    );
    if (result is Failure<ServiceDetailState>) {
      throw StateError(result.failure.message);
    }
    return (result as Success<ServiceDetailState>).value;
  }

  Future<void> details() async {
    if (selected == null || busy) return;
    var resumeReview = false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final local = await ref
          .read(registrationDraftStoreProvider)
          .read(selected!);
      final service = await current();
      var restored = local;
      if (service.assignment != null) {
        final server = await ref
            .read(registrationRepositoryProvider)
            .load(
              service.assignment!.assignmentId,
              service.schema.serviceSetup,
            );
        if (server is Failure<Map<String, dynamic>>) {
          if (mounted) setState(() => error = server.failure.message);
          return;
        }
        restored = mergeRegistrationSnapshot(
          local,
          (server as Success<Map<String, dynamic>>).value,
        );
        if (service.schema.serviceSetup.serviceAreasEnabled) {
          final options = service.schema.options
              .where((option) => service.selected.contains(option.optionId))
              .toList();
          if (options.any((option) => option.deliveryModes.isNotEmpty)) {
            final locations = await ref
                .read(registrationRepositoryProvider)
                .loadOptionLocations(service.assignment!.assignmentId, options);
            if (locations is Failure<Map<String, dynamic>>) {
              if (mounted) {
                setState(
                  () =>
                      error = 'Unable to load service locations. Please retry.',
                );
              }
              return;
            }
            restored['options'] = {
              ...(locations as Success<Map<String, dynamic>>).value,
              ...(restored['options'] as Map? ?? const {}),
            };
          }
        }
      }
      if (mounted) {
        setState(() {
          draft = restored;
          cached = service;
          final canResume =
              service.assignment != null &&
              service.validation == null &&
              validateRegistrationDraft(
                    service.schema,
                    service.selected,
                    restored,
                  ) ==
                  null;
          resumeReview =
              widget.initialStep == 0 && canResume && local['_step'] == 4;
          step = widget.initialStep == 3 && service.assignment != null
              ? 3
              : widget.initialStep == 0 && canResume
              ? 3
              : 2;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to restore your service details. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted && resumeReview) {
      await ref.read(documentsControllerProvider(selected!).notifier).load();
      if (mounted) await review();
    }
  }

  Future<bool> saveDraft(Map<String, dynamic> value) async {
    if (selected == null || busy) return false;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(registrationDraftStoreProvider).write(selected!, value);
      if (!mounted) return false;
      setState(() => draft = value);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to save progress on this device. Please retry.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveDetails(Map<String, dynamic> value) async {
    if (!await saveDraft(value) || !mounted) return;
    final service = await current();
    final validation = validateRegistrationDraft(
      service.schema,
      service.selected,
      value,
    );
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(serviceDetailControllerProvider(selected!).notifier)
          .continueSetup();
      if (!mounted || !saved) return;
      final updated = await current();
      if (updated.assignment == null) {
        throw StateError('Missing saved assignment');
      }
      final result = await saveRegistrationRequirements(
        ref.read(registrationRepositoryProvider),
        updated.assignment!.assignmentId,
        updated.schema,
        updated.selected,
        draft,
      );
      if (!mounted) return;
      if (result is Failure<void>) {
        setState(() => error = result.failure.message);
        return;
      }
      ref.read(providerCompletionControllerProvider.notifier).reload();
      ref.invalidate(providerAssignmentsProvider);
      setState(() {
        cached = updated;
        step = 3;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to save service details. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy || selected == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final service = await current();
      final id = service.assignment?.assignmentId;
      if (id == null) throw StateError('Missing assignment');
      final result = await saveRegistrationRequirements(
        ref.read(registrationRepositoryProvider),
        id,
        service.schema,
        service.selected,
        draft,
      );
      if (!mounted) return;
      if (result is Failure<void>) {
        setState(() => error = result.failure.message);
        return;
      }
      await ref.read(documentsControllerProvider(selected!).notifier).load();
      if (!mounted) return;
      final documents = ref.read(documentsControllerProvider(selected!)),
          now = ref.read(clockProvider)();
      if (documents.requirementsError != null ||
          documents.documentsError != null) {
        throw StateError('Document refresh failed');
      }
      if (applicableDocumentRequirements(
        documents.requirements ?? const [],
        service.selected,
      ).where((r) => r.required).any((r) {
        final status = documents.match(r.id, now)?.status(now);
        return status != 'Approved' && status != 'Pending approval';
      })) {
        setState(
          () => error = 'Upload all required documents before submitting.',
        );
        return;
      }
      final repo = ref.read(registrationRepositoryProvider);
      final snapshot = await repo.load(id, service.schema.serviceSetup);
      if (!mounted) return;
      if (snapshot is Failure<Map<String, dynamic>>) {
        setState(() => error = snapshot.failure.message);
        return;
      }
      final server = (snapshot as Success<Map<String, dynamic>>).value;
      for (final (resource, level) in [
        ('certificates', service.schema.serviceSetup.certificates.level),
        ('education', service.schema.serviceSetup.education.level),
      ]) {
        if (level != ProviderRequirementLevel.required) continue;
        final records = (server[resource] as List? ?? []).whereType<Map>();
        final valid = records.any((r) {
          if (r['verificationStatus'] == 'REJECTED') return false;
          final expiry = DateTime.tryParse(r['expiryDate']?.toString() ?? '');
          return expiry == null ||
              !expiry.isBefore(DateTime(now.year, now.month, now.day));
        });
        if (!valid) {
          setState(
            () => error = 'Add the required $resource before submitting.',
          );
          return;
        }
      }
      ref.read(providerCompletionControllerProvider.notifier).reload();
      ref.invalidate(providerAssignmentsProvider);
      final progress = await ref.read(
        providerCompletionControllerProvider.future,
      );
      await ref.read(providerAssignmentsProvider.future);
      if (!mounted) return;
      if (progress is! Success<ProviderCompletion>) {
        throw StateError('Progress unavailable');
      }
      final completion = progress.value.services
          .where((c) => c.assignmentId == id && c.serviceTypeId == selected)
          .firstOrNull;
      if (completion == null) throw StateError('Missing service progress');
      if (!progress.value.profileCompleted || !progress.value.marketSelected) {
        setState(
          () => error = 'Complete your profile and market before submitting.',
        );
        return;
      }
      if (service.schema.serviceSetup.availabilityEnabled &&
          !completion.availabilityCompleted) {
        setState(
          () => error = 'Your availability still needs attention. Review your days and times.',
        );
        return;
      }
      if (service.schema.serviceSetup.serviceAreasEnabled &&
          !completion.serviceAreasCompleted) {
        setState(
          () => error = 'Your service locations still need attention. Confirm each delivery mode and location.',
        );
        return;
      }
      if (completion.verificationStatus == 'REJECTED') {
        setState(
          () => error = 'Your service needs attention. Review rejected requirements before continuing.',
        );
        return;
      }
      submitted.add(selected!);
      allApproved =
          allApproved &&
          completion.verificationStatus == 'APPROVED' &&
          completion.effectiveStatus == 'ACTIVE';
      final nextService = chosen
          .where((id) => !submitted.contains(id))
          .firstOrNull;
      if (nextService != null) {
        setState(() {
          selected = nextService;
          cached = null;
          draft = {};
          step = 1;
          busy = false;
        });
        await details();
      } else {
        setState(() {
          approved = allApproved;
          step = 5;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to confirm your registration. Please retry. Your saved information is retained.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review() async {
    if (busy || cached?.assignment == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    final server = await ref
        .read(registrationRepositoryProvider)
        .load(cached!.assignment!.assignmentId, cached!.schema.serviceSetup);
    if (server is Success<Map<String, dynamic>>) {
      try {
        await ref.read(registrationDraftStoreProvider).write(selected!, {
          ...draft,
          '_step': 4,
        });
      } catch (_) {
        if (mounted)
          setState(() {
            busy = false;
            error = 'Unable to save progress on this device. Please retry.';
          });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (server is Success<Map<String, dynamic>>) {
        draft = {
          ...draft,
          'server': server.value,
          'documentNames':
              (ref.read(documentsControllerProvider(selected!)).documents ?? [])
                  .map((d) => d.name)
                  .toList(),
        };
        step = 4;
      } else {
        error = 'Unable to refresh your service for review. Please retry.';
      }
    });
  }

  void back() {
    if (busy) return;
    if (widget.initialStep == 3 && step == 3 && selected != null) {
      context.go(AppRoutes.serviceSetup(selected!));
      return;
    }
    if (step == 2 && widget.initialStep != 1) {
      context.pop();
    } else if (step == 1) {
      context.go(AppRoutes.services);
    } else {
      setState(() {
        step--;
        error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(providerServiceCatalogProvider),
        assignments = ref.watch(providerAssignmentsProvider);
    final detail = selected == null
        ? null
        : ref.watch(serviceDetailControllerProvider(selected!));
    final result = detail?.asData?.value;
    if (result is Success<ServiceDetailState>) cached = result.value;
    if (selected != null && step >= 3) {
      ref.watch(documentsControllerProvider(selected!));
    }
    if (step == 5) return RegistrationCompleteScreen(approved: approved);
    final saving =
        busy || (result is Success<ServiceDetailState> && result.value.busy);
    Widget content;
    if (step == 1) {
      final types = catalog.asData?.value, owned = assignments.asData?.value;
      if (catalog.isLoading || assignments.isLoading) {
        content = const BThereLoadingState(label: 'Loading services');
      } else if (types is Success<List<ProviderServiceType>> &&
          owned is Success<List<ProviderServiceAssignment>>) {
        content = RegistrationSelection(
          services: types.value,
          registeredIds: owned.value.map((a) => a.providerTypeId).toSet(),
          selected: selected,
          selectedIds: chosen,
          onSelect: (id) => setState(() {
            chosen.clear();
            chosen.add(id);
            selected = id;
            cached = null;
          }),
          onContinue: selected == null ? null : details,
          busy: busy,
        );
      } else {
        content = BThereStateView(
          title: 'Unable to load services',
          message: 'Please try again.',
          action: RegistrationButton(
            'Retry',
            onPressed: () {
              ref.read(providerServiceCatalogProvider.notifier).reload();
              ref.invalidate(providerAssignmentsProvider);
            },
          ),
        );
      }
    } else if (cached != null && cached!.service.id == selected) {
      final service = cached!;
      content = switch (step) {
        2 => RegistrationDetails(
          value: service,
          focusedOptionId: widget.optionId,
          draft: draft,
          busy: saving,
          onChange: () => setState(() {
            step = 1;
            error = null;
          }),
          onSaveDraft: saveDraft,
          onContinue: saveDetails,
        ),
        3 => RegistrationDocuments(
          serviceTypeId: selected!,
          assignmentId: service.assignment?.assignmentId,
          setup: service.schema.serviceSetup,
          selectedOptionIds: service.selected,
          onContinue: review,
        ),
        4 => RegistrationReview(
          value: service,
          draft: draft,
          onEdit: (v) => setState(() => step = v),
          onSubmit: submit,
          busy: saving,
        ),
        _ => const SizedBox.shrink(),
      };
    } else if (detail?.isLoading == true) {
      content = const BThereLoadingState(label: 'Loading service details');
    } else {
      content = BThereStateView(
        title: 'Unable to load service',
        message: 'Please try again.',
        action: RegistrationButton(
          'Retry',
          onPressed: () => ref
              .read(serviceDetailControllerProvider(selected!).notifier)
              .retry(),
        ),
      );
    }
    return RegistrationPage(
      step: step,
      onBack: back,
      busy: saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chosen.length > 1 && step > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: registrationText(
                'Service ${submitted.length + 1} of ${chosen.length}',
                11,
                color: registrationMuted,
              ),
            ),
          AbsorbPointer(absorbing: saving, child: content),
          if (error != null) ...[
            const SizedBox(height: 12),
            RegistrationNotice(error!, warning: true),
          ],
        ],
      ),
    );
  }
}

class RegistrationSelection extends StatelessWidget {
  const RegistrationSelection({
    required this.services,
    required this.registeredIds,
    required this.selected,
    this.selectedIds = const {},
    required this.onSelect,
    required this.onContinue,
    this.busy = false,
    super.key,
  });
  final List<ProviderServiceType> services;
  final Set<int> registeredIds;
  final int? selected;
  final Set<int> selectedIds;
  final ValueChanged<int> onSelect;
  final VoidCallback? onContinue;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final available = services
        .where((s) => !registeredIds.contains(s.id) || s.id == selected)
        .toList();
    final registered = services
        .where((s) => registeredIds.contains(s.id) && s.id != selected)
        .toList();
    Widget grid(List<ProviderServiceType> items, {bool owned = false}) => Wrap(
      spacing: 11,
      runSpacing: 11,
      children: [
        for (final service in items)
          SizedBox(
            width: 183.5,
            child: RegistrationCategory(
              service: service,
              selected: selectedIds.isNotEmpty
                  ? selectedIds.contains(service.id)
                  : service.id == selected,
              registered: owned,
              onTap: busy ? null : () => onSelect(service.id),
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RegistrationHeading(
          'What service do you offer?',
          'Choose one service to get started.',
          fontFamily: 'Nunito',
        ),
        if (services.isEmpty)
          const RegistrationNotice('No services are currently available.'),
        grid(available),
        if (registered.isNotEmpty) ...[
          const SizedBox(height: 25),
          RegistrationSection(
            'Registered Services',
            'Already registered services',
            child: grid(registered, owned: true),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF3FCFB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 49,
                height: 49,
                child: RegistrationAsset('selection_imgOpportunitiesSymbol'),
              ),
              const SizedBox(width: 19),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    registrationText(
                      'More services coming soon',
                      13.5,
                      bold: true,
                    ),
                    const SizedBox(height: 3),
                    registrationText(
                      'We’re always adding new opportunities to support more skills.',
                      12.3,
                      color: registrationMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        RegistrationButton('Continue', onPressed: onContinue, busy: busy),
      ],
    );
  }
}

class RegistrationCategory extends StatelessWidget {
  const RegistrationCategory({
    required this.service,
    required this.onTap,
    this.selected = false,
    this.registered = false,
    super.key,
  });
  final ProviderServiceType service;
  final VoidCallback? onTap;
  final bool selected, registered;
  @override
  Widget build(BuildContext context) {
    final visual = serviceVisualStyle(service);
    final badge = visual.badge ?? visual.surface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: visual.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? registrationTeal : visual.surface,
            width: .8,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 15, 8, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: badge,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Center(
                        child: const Icon(
                          Icons.miscellaneous_services,
                          color: registrationTeal,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    registrationText(
                      service.name,
                      13.4,
                      bold: true,
                      fontFamily: 'Nunito',
                      weight: FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
