import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../application/service_setup_controller.dart';
import '../presentation/service_setup_screen.dart';
import 'document_models.dart';
import 'documents_controller.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  ServiceSetupData? entered;
  @override
  void didUpdateWidget(covariant DocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceTypeId != widget.serviceTypeId) entered = null;
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(
      serviceSetupControllerProvider(widget.serviceTypeId),
    );
    final result = setup.asData?.value;
    if (result is Success<ServiceSetupData> && result.value.selectionValid) {
      entered = result.value;
    }
    if (entered == null) {
      return ServiceSetupScreen(serviceTypeId: widget.serviceTypeId);
    }
    return DocumentsContent(
      serviceTypeId: widget.serviceTypeId,
      serviceName: entered!.schema.serviceName,
    );
  }
}

class DocumentsContent extends ConsumerStatefulWidget {
  const DocumentsContent({
    required this.serviceTypeId,
    required this.serviceName,
    super.key,
  });
  final int serviceTypeId;
  final String serviceName;
  @override
  ConsumerState<DocumentsContent> createState() => _DocumentsContentState();
}

class _DocumentsContentState extends ConsumerState<DocumentsContent> {
  bool _editorOpen = false;
  int get serviceTypeId => widget.serviceTypeId;
  String get serviceName => widget.serviceName;

  Future<void> openEditor(DocumentRequirement requirement) async {
    final controller = ref.read(
      documentsControllerProvider(serviceTypeId).notifier,
    );
    if (_editorOpen ||
        ref.read(documentsControllerProvider(serviceTypeId)).busy) {
      return;
    }
    controller.edit(requirement);
    if (ref.read(documentsControllerProvider(serviceTypeId)).draft == null) {
      return;
    }
    final container = ProviderScope.containerOf(context);
    final selectedServiceId = serviceTypeId;
    setState(() => _editorOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: DocumentEditorSheet(serviceTypeId: selectedServiceId),
        ),
      );
    } finally {
      if (mounted) {
        controller.cancel();
        setState(() => _editorOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentsControllerProvider(serviceTypeId));
    final controller = ref.read(
      documentsControllerProvider(serviceTypeId).notifier,
    );
    final now = ref.watch(clockProvider)();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !state.busy) {
          context.go(AppRoutes.serviceSetup(serviceTypeId));
        }
      },
      child: OnboardingPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$serviceName Documents',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text('Upload the documents required for this service.'),
            if (state.requirementsLoading) ...[
              const SizedBox(height: 16),
              const BThereLoadingState(
                label: 'Loading document requirements',
                compact: true,
              ),
            ],
            if (state.documentsLoading) ...[
              const SizedBox(height: 16),
              const BThereLoadingState(
                label: 'Loading your documents',
                compact: true,
              ),
            ],
            if (state.requirementsError != null) Text(state.requirementsError!),
            if (state.documentsError != null) Text(state.documentsError!),
            if (state.requirements?.isEmpty == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No documents are required for this service.'),
              ),
            for (final requirement
                in state.requirements ?? <DocumentRequirement>[]) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      final document = state.match(requirement.id, now);
                      final status =
                          document?.status(now) ??
                          (state.documentsError != null ||
                                  state.documentsLoading
                              ? 'Status unavailable'
                              : 'Not uploaded');
                      final approved = status == 'Approved';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            requirement.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (requirement.description != null)
                            Text(requirement.description!),
                          Text(requirement.required ? 'Required' : 'Optional'),
                          if (requirement.requiresApproval)
                            const Text('Approval required'),
                          Text('Status: $status'),
                          if (document != null) ...[
                            Text(document.name),
                            Text(document.number),
                            Text('Issued: ${document.issuedDate}'),
                            if (document.expiryDate != null)
                              Text(
                                'Expires: ${document.expiryDate!.toIso8601String().substring(0, 10)}',
                              ),
                          ],
                          if (approved)
                            const Text(
                              'Your shared Provider document satisfies this requirement.',
                            ),
                          if (document?.verificationStatus == 'REJECTED' &&
                              document?.rejectionReason != null)
                            Text(document!.rejectionReason!),
                          if (!approved && document != null)
                            const Text(
                              'Replacing this shared document resets its verification to pending and may affect other services.',
                            ),
                          if (!approved &&
                              !state.documentsLoading &&
                              !state.requirementsLoading &&
                              state.requirementsError == null &&
                              state.documentsError == null)
                            BThereButton(
                              label: document == null
                                  ? 'Upload document'
                                  : 'Replace document',
                              enabled: !state.busy && !_editorOpen,
                              onPressed: () => openEditor(requirement),
                            ),
                          if (document != null &&
                              [
                                'PENDING',
                                'REJECTED',
                              ].contains(document.verificationStatus))
                            TextButton(
                              onPressed: state.busy
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete document?'),
                                          content: Text(
                                            'Remove your shared ${requirement.name} document? This may affect other services.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await controller.delete(document);
                                      }
                                    },
                              child: const Text('Delete document'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
            if (!_editorOpen && state.phase != null) ...[
              Text(state.phase!),
              const LinearProgressIndicator(),
            ],
            if (!_editorOpen && state.operationError != null)
              Text(state.operationError!),
            if (state.notice != null) Text(state.notice!),
            const SizedBox(height: 24),
            BThereButton(
              label:
                  state.requirementsError != null ||
                      state.documentsError != null
                  ? 'Retry refresh'
                  : 'Refresh',
              enabled:
                  !state.busy &&
                  !state.requirementsLoading &&
                  !state.documentsLoading,
              onPressed: controller.load,
            ),
            TextButton(
              onPressed: state.busy
                  ? null
                  : () => context.go(AppRoutes.serviceSetup(serviceTypeId)),
              child: const Text('Back to service setup'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Presentation only: all file, metadata, upload and retry state belongs to
/// the existing service-keyed DocumentsController.
class DocumentEditorSheet extends ConsumerStatefulWidget {
  const DocumentEditorSheet({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  ConsumerState<DocumentEditorSheet> createState() =>
      _DocumentEditorSheetState();
}

class _DocumentEditorSheetState extends ConsumerState<DocumentEditorSheet> {
  bool _closing = false;
  final _errorKey = GlobalKey();
  void closeWhenFinished(DocumentsState state) {
    if (_closing || state.draft != null || state.busy) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final route = ModalRoute.of(context);
        if (route != null) {
          final navigator = Navigator.of(context);
          if (route.isCurrent) {
            navigator.pop();
          } else if (route.isActive) {
            navigator.removeRoute(route);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = documentsControllerProvider(widget.serviceTypeId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (_, next) {
      closeWhenFinished(next);
      if (next.operationError != null && !next.busy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final errorContext = _errorKey.currentContext;
          if (mounted && errorContext != null) {
            Scrollable.ensureVisible(errorContext);
          }
        });
      }
    });
    final draft = state.draft;
    return PopScope(
      canPop: !state.busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _closing = true;
          controller.cancel();
        }
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (draft != null) ...[
                  Text(
                    'Submit ${draft.requirement.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text('PDF, JPG, JPEG, PNG or WebP. Maximum 100 MB.'),
                  BThereButton(
                    label: 'Choose file',
                    enabled: !state.busy,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      controller.pick();
                    },
                  ),
                  if (draft.file != null) Text(draft.file!.name),
                  DocumentMetadataForm(
                    key: ObjectKey(draft),
                    draft: draft,
                    enabled: !state.busy,
                  ),
                ],
                if (state.phase != null) Text(state.phase!),
                if (state.busy)
                  LinearProgressIndicator(
                    value: state.phase == 'Uploading document'
                        ? state.progress
                        : null,
                  ),
                if (state.operationError != null)
                  Text(
                    state.operationError!,
                    key: _errorKey,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                if (draft != null)
                  BThereButton(
                    label: draft.upload != null
                        ? 'Retry registration'
                        : 'Upload and submit',
                    loading: state.busy,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      controller.submit();
                    },
                  ),
                TextButton(
                  onPressed: state.busy ? null : controller.cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DocumentMetadataForm extends StatelessWidget {
  const DocumentMetadataForm({
    required this.draft,
    required this.enabled,
    super.key,
  });
  final DocumentDraft draft;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextFormField(
        initialValue: draft.name,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: 'Document name',
          errorText: draft.errors['name'],
        ),
        onChanged: (v) => draft.name = v,
      ),
      TextFormField(
        initialValue: draft.number,
        enabled: enabled,
        decoration: const InputDecoration(labelText: 'Document number'),
        onChanged: (v) => draft.number = v,
      ),
      TextFormField(
        initialValue: draft.issued,
        enabled: enabled,
        decoration: InputDecoration(
          errorText: draft.errors['issued'],
          labelText: 'Issued date (YYYY-MM-DD)',
        ),
        onChanged: (v) => draft.issued = v,
      ),
      if (draft.requirement.hasExpiry)
        TextFormField(
          initialValue: draft.expiry,
          enabled: enabled,
          decoration: InputDecoration(
            errorText: draft.errors['expiry'],
            labelText: 'Expiry date (YYYY-MM-DD)',
          ),
          onChanged: (v) => draft.expiry = v,
        ),
    ],
  );
}
