import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Submit ${draft.requirement.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    draft.requirement.isSelfie
                        ? 'Take a clear selfie with your face fully visible and good lighting.'
                        : 'Photograph the full document. Keep all text clear and avoid glare.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: Icon(
                      draft.requirement.isSelfie
                          ? Icons.add_a_photo_outlined
                          : Icons.camera_alt_outlined,
                    ),
                    label: Text(
                      draft.requirement.isSelfie ? 'Take selfie' : 'Take photo',
                    ),
                    onPressed: state.busy
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            controller.pick(camera: true);
                          },
                  ),
                  const SizedBox(height: 8),
                  BThereButton(
                    label: 'Choose file',
                    enabled: !state.busy,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      controller.pick();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF, JPG, JPEG, PNG or WebP. Maximum 100 MB.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (draft.file != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline),
                          const SizedBox(width: 12),
                          Expanded(child: Text(draft.file!.name)),
                          Text(
                            '${(draft.file!.size / 1000000).toStringAsFixed(1)} MB',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Document details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
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
                if (state.cameraSettingsRequired)
                  TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final opened = await openAppSettings();
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Open your phone Settings and allow camera access for this app.',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open Settings'),
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
    children:
        [
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
              DocumentDateField(
                value: draft.issued,
                enabled: enabled,
                label: 'Issued date (YYYY-MM-DD)',
                error: draft.errors['issued'],
                onChanged: (value) => draft.issued = value,
              ),
              if (draft.requirement.hasExpiry)
                DocumentDateField(
                  value: draft.expiry,
                  enabled: enabled,
                  label: 'Expiry date (YYYY-MM-DD)',
                  error: draft.errors['expiry'],
                  onChanged: (value) => draft.expiry = value,
                ),
            ]
            .map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: field,
              ),
            )
            .toList(),
  );
}

class DocumentDateField extends StatefulWidget {
  const DocumentDateField({
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
    this.error,
    super.key,
  });
  final String value, label;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  State<DocumentDateField> createState() => _DocumentDateFieldState();
}

class _DocumentDateFieldState extends State<DocumentDateField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  bool _picking = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocumentDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _text.text) _text.text = widget.value;
  }

  Future<void> _choose() async {
    if (_picking || !widget.enabled) return;
    _picking = true;
    FocusScope.of(context).unfocus();
    try {
      final first = DateTime(1900);
      final last = DateTime(2200, 12, 31);
      final parsed = DateTime.tryParse(_text.text) ?? DateTime.now();
      final date = await showDatePicker(
        context: context,
        helpText: widget.label.split(' (').first,
        initialDate: parsed.isBefore(first)
            ? first
            : (parsed.isAfter(last) ? last : parsed),
        firstDate: first,
        lastDate: last,
      );
      if (date != null && mounted) {
        final value = date.toIso8601String().substring(0, 10);
        _text.text = value;
        widget.onChanged(value);
        setState(() {});
      }
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _text,
    enabled: widget.enabled,
    readOnly: true,
    onTap: _choose,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.error,
      suffixIcon: IconButton(
        tooltip: 'Choose ${widget.label.split(' (').first.toLowerCase()}',
        onPressed: widget.enabled ? _choose : null,
        icon: const Icon(Icons.calendar_today_outlined),
      ),
    ),
  );
}
