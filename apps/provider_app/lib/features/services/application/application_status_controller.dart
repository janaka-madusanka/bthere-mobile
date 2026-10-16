import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../data/registration_repository.dart';
import '../documents/document_models.dart';
import '../documents/documents_controller.dart';
import 'registration_draft.dart';
import 'registration_payload.dart';
import 'service_detail_controller.dart';
import 'service_providers.dart';

enum ApplicationItemKind {
  document,
  skill,
  option,
  certificate,
  education,
  field,
}

enum ApplicationItemState {
  pending,
  approved,
  rejected,
  missing,
  expired,
  reuploaded,
  unknown,
}

class ApplicationReviewItem {
  const ApplicationReviewItem({
    required this.id,
    required this.label,
    required this.kind,
    required this.state,
    this.reason,
    this.optionId,
    this.document,
  });
  final String id, label;
  final ApplicationItemKind kind;
  final ApplicationItemState state;
  final String? reason;
  final int? optionId;
  final DocumentRequirement? document;
  bool get needsCorrection => [
    ApplicationItemState.rejected,
    ApplicationItemState.expired,
    ApplicationItemState.missing,
  ].contains(state);
}

class ApplicationStatusData {
  const ApplicationStatusData({
    required this.service,
    required this.completion,
    required this.items,
  });
  final ServiceDetailState service;
  final ProviderServiceCompletion completion;
  final List<ApplicationReviewItem> items;
  bool get approved => !pending && completion.verificationStatus == 'APPROVED';
  bool get pending =>
      completion.verificationStatus == 'PENDING' ||
      service.registered.any(
        (option) => option.verificationStatus == 'PENDING',
      );
  bool get rejected =>
      completion.verificationStatus == 'REJECTED' ||
      service.assignment?.verificationStatus == 'REJECTED' ||
      service.registered.any(
        (option) => option.verificationStatus == 'REJECTED',
      );
  bool get inactive =>
      completion.effectiveStatus == 'INACTIVE' ||
      service.assignment?.providerStatus == 'INACTIVE' ||
      service.assignment?.adminStatus == 'INACTIVE';
  String? get reason => service.assignment?.rejectionReason;
  ApplicationReviewItem? get correction =>
      items.where((item) => item.needsCorrection).firstOrNull;
}

ApplicationItemState applicationItemState(Object? state) => switch (state) {
  'PENDING' => ApplicationItemState.pending,
  'APPROVED' => ApplicationItemState.approved,
  'REJECTED' => ApplicationItemState.rejected,
  null => ApplicationItemState.missing,
  _ => ApplicationItemState.unknown,
};

List<ApplicationReviewItem> applicationReviewItems({
  required ServiceDetailState service,
  required List<DocumentRequirement> requirements,
  required List<ProviderDocument> documents,
  required Map<String, dynamic> snapshot,
  required DateTime now,
  Map reuploaded = const {},
}) {
  final items = <ApplicationReviewItem>[];
  final seen = <int>{};
  for (final requirement in requirements) {
    if (requirement.optionId != null &&
            !service.selected.contains(requirement.optionId) ||
        !seen.add(requirement.id)) {
      continue;
    }
    final matches =
        documents
            .where((document) => document.typeId == requirement.id)
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
              a.createdAt ?? DateTime(1970),
            ),
          );
    final document =
        matches
            .where((document) => document.status(now) == 'Approved')
            .firstOrNull ??
        matches.firstOrNull;
    if (document == null && !requirement.required) continue;
    var state = document?.status(now) == 'Expired'
        ? ApplicationItemState.expired
        : applicationItemState(document?.verificationStatus);
    if (state == ApplicationItemState.pending &&
        document != null &&
        reuploaded['${requirement.id}'] == document.key) {
      state = ApplicationItemState.reuploaded;
    }
    items.add(
      ApplicationReviewItem(
        id: 'document-${requirement.id}',
        label: requirement.name,
        kind: ApplicationItemKind.document,
        state: state,
        reason: document?.rejectionReason,
        document: requirement,
      ),
    );
  }
  List<Map> records(String name) =>
      (snapshot[name] as List? ?? []).whereType<Map>().toList();
  final skills = records('skills');
  for (final configured in service.schema.serviceSetup.skills) {
    final skill = skills
        .where((skill) => skill['skillId'] == configured.metadata['skillId'])
        .firstOrNull;
    if (skill == null && configured.metadata['required'] != true) continue;
    items.add(
      ApplicationReviewItem(
        id: 'skill-${configured.metadata['skillId']}',
        label: configured.metadata['name'] as String,
        kind: ApplicationItemKind.skill,
        state: applicationItemState(skill?['verificationStatus']),
        reason: skill?['rejectionReason'] as String?,
      ),
    );
  }
  for (final option in service.schema.options.where(
    (option) => service.selected.contains(option.optionId),
  )) {
    final selected = service.registered
        .where((record) => record.optionId == option.optionId)
        .firstOrNull;
    items.add(
      ApplicationReviewItem(
        id: 'option-${option.optionId}',
        label: option.name,
        kind: ApplicationItemKind.option,
        state: applicationItemState(selected?.verificationStatus),
        reason: selected?.reviewNote,
        optionId: option.optionId,
      ),
    );
  }
  for (final (resource, kind, level, label) in [
    (
      'certificates',
      ApplicationItemKind.certificate,
      service.schema.serviceSetup.certificates.level,
      'Certificate',
    ),
    (
      'education',
      ApplicationItemKind.education,
      service.schema.serviceSetup.education.level,
      'Education',
    ),
  ]) {
    if (level == ProviderRequirementLevel.disabled) continue;
    final entries = records(resource);
    if (entries.isEmpty && level == ProviderRequirementLevel.required) {
      items.add(
        ApplicationReviewItem(
          id: resource,
          label: label,
          kind: kind,
          state: ApplicationItemState.missing,
        ),
      );
    }
    for (final (index, record) in entries.indexed) {
      final expiry = DateTime.tryParse(record['expiryDate']?.toString() ?? '');
      items.add(
        ApplicationReviewItem(
          id: '$resource-${record['certificateId'] ?? record['educationId'] ?? index}',
          label:
              (record['name'] ?? record['qualificationName']) as String? ??
              label,
          kind: kind,
          state:
              expiry != null &&
                  expiry.isBefore(DateTime(now.year, now.month, now.day))
              ? ApplicationItemState.expired
              : applicationItemState(record['verificationStatus']),
          reason: record['rejectionReason'] as String?,
        ),
      );
    }
  }
  final submissions = records('submissions');
  for (final field in activeRegistrationFields(
    service.schema,
    service.selected,
  )) {
    final submission = submissions
        .where((record) => record['fieldId'] == field.fieldId)
        .firstOrNull;
    if (submission == null && !field.required) continue;
    final answers = {
      for (final record in submissions) '${record['fieldId']}': record['value'],
    };
    if (registrationFieldVisible(
          field,
          answers,
          activeRegistrationFields(service.schema, service.selected),
        ) ==
        false) {
      continue;
    }
    items.add(
      ApplicationReviewItem(
        id: 'field-${field.fieldId}',
        label: field.label,
        kind: ApplicationItemKind.field,
        state: applicationItemState(submission?['verificationStatus']),
        reason: submission?['reviewNote'] as String?,
        optionId: field.optionIds.where(service.selected.contains).firstOrNull,
      ),
    );
  }
  return List.unmodifiable(items);
}

final applicationStatusProvider = AsyncNotifierProvider.autoDispose
    .family<ApplicationStatusController, Result<ApplicationStatusData>, int>(
      ApplicationStatusController.new,
      dependencies: [
        serviceDetailControllerProvider,
        providerCompletionControllerProvider,
        documentsRepositoryProvider,
        registrationRepositoryProvider,
        registrationDraftStoreProvider,
        clockProvider,
      ],
    );

class ApplicationStatusController
    extends AsyncNotifier<Result<ApplicationStatusData>> {
  ApplicationStatusController(this.serviceTypeId);
  final int serviceTypeId;
  @override
  Future<Result<ApplicationStatusData>> build() async {
    try {
      final service = await ref.watch(
        serviceDetailControllerProvider(serviceTypeId).future,
      );
      final progress = await ref.watch(
        providerCompletionControllerProvider.future,
      );
      if (service is! Success<ServiceDetailState> ||
          service.value.assignment == null ||
          progress is! Success<ProviderCompletion>) {
        return failure();
      }
      final completion = progress.value.services
          .where(
            (record) =>
                record.serviceTypeId == serviceTypeId &&
                record.assignmentId == service.value.assignment!.assignmentId,
          )
          .firstOrNull;
      if (completion == null) return failure();
      final documents = ref.watch(documentsRepositoryProvider),
          repository = ref.watch(registrationRepositoryProvider);
      final results = await Future.wait<Object>([
        documents.requirements(serviceTypeId),
        documents.documents(),
        repository.load(
          service.value.assignment!.assignmentId,
          service.value.schema.serviceSetup,
        ),
      ]);
      if (!ref.mounted ||
          results[0] is! Success<List<DocumentRequirement>> ||
          results[1] is! Success<List<ProviderDocument>> ||
          results[2] is! Success<Map<String, dynamic>>) {
        return failure();
      }
      final reuploads = await ref
          .watch(registrationDraftStoreProvider)
          .reviewUploads(serviceTypeId);
      if (!ref.mounted) return failure();
      return Success(
        ApplicationStatusData(
          service: service.value,
          completion: completion,
          items: applicationReviewItems(
            service: service.value,
            requirements:
                (results[0] as Success<List<DocumentRequirement>>).value,
            documents: (results[1] as Success<List<ProviderDocument>>).value,
            snapshot: (results[2] as Success<Map<String, dynamic>>).value,
            now: ref.watch(clockProvider)(),
            reuploaded: reuploads,
          ),
        ),
      );
    } catch (_) {
      return failure();
    }
  }

  Failure<ApplicationStatusData> failure() => const Failure(
    AppFailure(
      message: 'Unable to load your application status. Please retry.',
    ),
  );
  Future<void> refresh() async {
    if (state.isLoading) return;
    final container = ref.container;
    container.read(providerCompletionControllerProvider.notifier).reload();
    container.invalidate(providerAssignmentsProvider);
    container.invalidate(serviceDetailControllerProvider(serviceTypeId));
    container.invalidate(applicationStatusProvider(serviceTypeId));
    await container.read(applicationStatusProvider(serviceTypeId).future);
  }
}
