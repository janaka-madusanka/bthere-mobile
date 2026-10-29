import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../documents/document_models.dart';
import '../documents/documents_controller.dart';
import '../documents/documents_screen.dart';
import 'registration_widgets.dart';
import 'registration_qualifications.dart';
import '../documents/document_preview_cache.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';

List<DocumentRequirement> applicableDocumentRequirements(
  Iterable<DocumentRequirement> requirements,
  Set<int> selectedOptionIds,
) {
  final byType = <int, DocumentRequirement>{};
  for (final requirement in requirements) {
    if (requirement.optionId == null ||
        selectedOptionIds.contains(requirement.optionId)) {
      byType.putIfAbsent(requirement.id, () => requirement);
    }
  }
  return byType.values.toList();
}

class RegistrationDocuments extends ConsumerStatefulWidget {
  const RegistrationDocuments({
    required this.serviceTypeId,
    required this.onContinue,
    this.assignmentId,
    this.setup,
    this.selectedOptionIds = const {},
    super.key,
  });
  final int serviceTypeId;
  final int? assignmentId;
  final ProviderServiceSetup? setup;
  final Set<int> selectedOptionIds;
  final VoidCallback onContinue;
  @override
  ConsumerState<RegistrationDocuments> createState() => _DocumentsState();
}

class _DocumentsState extends ConsumerState<RegistrationDocuments> {
  bool editorOpen = false;
  Future<void> edit(DocumentRequirement requirement) async {
    final controller = ref.read(
      documentsControllerProvider(widget.serviceTypeId).notifier,
    );
    if (editorOpen) return;
    controller.edit(requirement);
    if (ref.read(documentsControllerProvider(widget.serviceTypeId)).draft ==
        null) {
      return;
    }
    final container = ProviderScope.containerOf(context);
    setState(() => editorOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: DocumentEditorSheet(serviceTypeId: widget.serviceTypeId),
        ),
      );
    } finally {
      if (mounted) {
        controller.cancel();
        setState(() => editorOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsControllerProvider(widget.serviceTypeId));
    final controller = ref.read(
      documentsControllerProvider(widget.serviceTypeId).notifier,
    );
    final now = ref.watch(clockProvider)();
    final previews = ref.watch(documentPreviewCacheProvider);
    final loading = state.requirementsLoading || state.documentsLoading;
    final error = state.requirementsError ?? state.documentsError;
    final required = applicableDocumentRequirements(
      state.requirements ?? const <DocumentRequirement>[],
      widget.selectedOptionIds,
    );
    final ready =
        !loading &&
        error == null &&
        required.where((r) => r.required).every((r) {
          final status = state.match(r.id, now)?.status(now);
          return status == 'Approved' || status == 'Pending approval';
        });
    Widget card(DocumentRequirement requirement) {
      final document = state.match(requirement.id, now);
      final status = document?.status(now);
      final approved = status == 'Approved';
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RegistrationPanel(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFFBFA),
                  shape: BoxShape.circle,
                ),
                child: const RegistrationAsset('documents_imgDocumentType'),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 9,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        registrationText(requirement.name, 11, bold: true),
                        if (requirement.required)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEAF0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: registrationText(
                              'Required',
                              8.6,
                              color: const Color(0xFFFF174C),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    registrationText(
                      document == null
                          ? requirement.description ??
                                'Upload a clear copy of your document.'
                          : '${document.name} · $status',
                      10,
                      color: registrationMuted,
                    ),
                    if (document?.rejectionReason != null)
                      registrationText(
                        document!.rejectionReason!,
                        10,
                        color: Colors.red,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (document != null && previews[document.key] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    previews[document.key]!,
                    width: 42,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.description_outlined),
                  ),
                ),
              IconButton.outlined(
                tooltip: approved
                    ? 'Document approved'
                    : document == null
                    ? 'Upload ${requirement.name}'
                    : 'Replace ${requirement.name}',
                onPressed: loading || state.busy || editorOpen || approved
                    ? null
                    : () => edit(requirement),
                icon: approved
                    ? const Icon(Icons.check_circle, color: registrationTeal)
                    : document == null
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: RegistrationAsset('documents_imgAddDocument'),
                      )
                    : const Icon(
                        Icons.edit_outlined,
                        size: 21,
                        color: registrationTeal,
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RegistrationHeading(
          'Upload Required Documents',
          'Provide the necessary documents to verify your qualifications and help build trust with clients.',
        ),
        const RegistrationNotice(
          'All documents must be clear, valid, and in the required format. Accepted formats: PDF, JPG, JPEG, PNG, WebP (Max 100 MB each).',
        ),
        const SizedBox(height: 20),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null) ...[
          RegistrationNotice(error, warning: true),
          TextButton(onPressed: controller.load, child: const Text('Retry')),
        ],
        RegistrationSection(
          'Common Documents',
          'Your uploaded documents are shared across your services.',
          child: Column(
            children: [
              for (final requirement in required.where(
                (r) => r.optionId == null,
              ))
                card(requirement),
            ],
          ),
        ),
        RegistrationSection(
          'Service Specific Documents',
          'These documents are required for the services you have selected.',
          child: Column(
            children: [
              for (final requirement in required.where(
                (r) => r.optionId != null,
              ))
                card(requirement),
              if (!loading && required.isEmpty && error == null)
                const RegistrationNotice(
                  'No documents are required for this service.',
                ),
            ],
          ),
        ),
        if (state.documents?.isNotEmpty == true)
          RegistrationSection(
            'Review Uploaded Documents',
            'Make sure your documents are clear and correct before continuing.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final document in state.documents!)
                  SizedBox(
                    width: 120,
                    child: InkWell(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(document.name),
                          content: Text(
                            '${document.typeName}\nIssued: ${document.issuedDate}\nStatus: ${document.status(now)}',
                          ),
                          actions: [
                            if (document.verificationStatus != 'APPROVED')
                              TextButton(
                                onPressed: state.busy
                                    ? null
                                    : () async {
                                        Navigator.pop(context);
                                        await controller.delete(document);
                                      },
                                child: const Text('Delete document'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      child: RegistrationPanel(
                        padding: const EdgeInsets.all(9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            registrationText(document.name, 9, bold: true),
                            const SizedBox(height: 12),
                            Center(
                              child: SizedBox(
                                width: 100,
                                height: 110,
                                child: previews[document.key] != null
                                    ? Image.memory(
                                        previews[document.key]!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.description_outlined,
                                        ),
                                      )
                                    : state.viewUrls[document.key] != null
                                    ? Image.network(
                                        state.viewUrls[document.key].toString(),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const Padding(
                                              padding: EdgeInsets.all(26),
                                              child: RegistrationAsset(
                                                'documents_imgDocumentType',
                                              ),
                                            ),
                                      )
                                    : const Padding(
                                        padding: EdgeInsets.all(26),
                                        child: RegistrationAsset(
                                          'documents_imgDocumentType',
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            registrationText(
                              document.status(now),
                              9,
                              color: registrationTeal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (state.operationError != null)
          RegistrationNotice(state.operationError!, warning: true),
        if (widget.assignmentId != null && widget.setup != null)
          RegistrationQualifications(
            assignmentId: widget.assignmentId!,
            setup: widget.setup!,
          ),
        const RegistrationNotice(
          'Ensure all information is readable. Blurry or unclear documents may delay your verification process.',
          warning: true,
        ),
        const SizedBox(height: 16),
        RegistrationButton(
          'Continue',
          onPressed: ready && !state.busy && !editorOpen
              ? widget.onContinue
              : null,
        ),
      ],
    );
  }
}
