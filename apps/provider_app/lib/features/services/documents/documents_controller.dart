import 'package:bthere_common/bthere_common.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../application/service_setup_controller.dart';
import 'document_models.dart';
import 'documents_repository.dart';

void _documentTrace(String event) {
  if (kDebugMode) debugPrint('[ProviderDocuments] $event');
}

final documentsRepositoryProvider = Provider<DocumentsRepository>(
  (ref) => ApiDocumentsRepository(ref.watch(apiClientProvider)),
  dependencies: [apiClientProvider],
);

abstract interface class DocumentPicker {
  Future<DocumentFile?> pick();
}

class NativeDocumentPicker implements DocumentPicker {
  @override
  Future<DocumentFile?> pick() async {
    _documentTrace('native.request');
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: documentExtensions,
    );
    _documentTrace(file == null ? 'native.cancelled' : 'native.returned');
    if (file == null) return null;
    _documentTrace('file.size.start');
    final size = await file.length() ?? 0;
    _documentTrace('file.size.completed');
    return DocumentFile(file.name, size, () => file.readAsByteStream());
  }
}

final documentPickerProvider = Provider<DocumentPicker>(
  (ref) => NativeDocumentPicker(),
);

class DocumentDraft {
  DocumentDraft(this.requirement) : name = requirement.name;
  final DocumentRequirement requirement;
  String name, number = '', issued = '', expiry = '';
  DocumentFile? file;
  DocumentUpload? upload;
  final Map<String, String> errors = {};
}

class DocumentsState {
  List<DocumentRequirement>? requirements;
  List<ProviderDocument>? documents;
  String? requirementsError, documentsError, operationError, notice;
  bool requirementsLoading = true, documentsLoading = true, busy = false;
  String? phase;
  double? progress;
  DocumentDraft? draft;
  ProviderDocument? match(int typeId, DateTime now) {
    final matches = documents?.where((d) => d.typeId == typeId).toList() ?? [];
    return matches.where((d) => d.status(now) == 'Approved').firstOrNull ??
        matches.firstOrNull;
  }
}

final documentsControllerProvider = NotifierProvider.autoDispose
    .family<DocumentsController, DocumentsState, int>(
      DocumentsController.new,
      dependencies: [
        documentsRepositoryProvider,
        documentPickerProvider,
        serviceSetupControllerProvider,
        providerCompletionControllerProvider,
        clockProvider,
      ],
    );

class DocumentsController extends Notifier<DocumentsState> {
  DocumentsController(this.serviceTypeId);
  final int serviceTypeId;
  @override
  DocumentsState build() {
    final value = DocumentsState();
    Future.microtask(load);
    return value;
  }

  void emit() {
    if (ref.mounted) ref.notifyListeners();
  }

  bool _loading = false;
  Future<Result<T>> safe<T>(Future<Result<T>> Function() operation) async {
    try {
      return await operation();
    } catch (_) {
      return const Failure(
        AppFailure(message: 'Unable to load documents. Please retry.'),
      );
    }
  }

  Future<void> load() async {
    if (!ref.mounted || state.busy || _loading) return;
    _loading = true;
    late DocumentsRepository repo;
    try {
      repo = ref.read(documentsRepositoryProvider);
    } catch (_) {
      state.requirementsLoading = state.documentsLoading = false;
      state.requirementsError =
          'Unable to load document requirements. Please retry.';
      state.documentsError = 'Unable to load your documents. Please retry.';
      _loading = false;
      emit();
      return;
    }
    state.requirementsLoading = state.documentsLoading = true;
    state.requirementsError = state.documentsError = null;
    emit();
    await Future.wait([
      () async {
        final result = await safe(() => repo.requirements(serviceTypeId));
        if (!ref.mounted) return;
        state.requirementsLoading = false;
        if (result case Success<List<DocumentRequirement>>(:final value)) {
          state.requirements = value;
        } else {
          state.requirementsError =
              'Unable to load document requirements. Please retry.';
        }
        emit();
      }(),
      () async {
        final result = await safe(repo.documents);
        if (!ref.mounted) return;
        state.documentsLoading = false;
        if (result case Success<List<ProviderDocument>>(:final value)) {
          state.documents = value;
        } else {
          state.documentsError = 'Unable to load your documents. Please retry.';
        }
        emit();
      }(),
    ]);
    _loading = false;
  }

  void edit(DocumentRequirement requirement) {
    if (state.busy ||
        state.requirementsLoading ||
        state.requirementsError != null ||
        state.documentsLoading ||
        state.documentsError != null) {
      return;
    }
    final previous = state.match(requirement.id, ref.read(clockProvider)());
    if (previous?.status(ref.read(clockProvider)()) == 'Approved') {
      return;
    }
    trace('edit.open hasExpiry=${requirement.hasExpiry}');
    state.draft = DocumentDraft(requirement);
    if (previous != null) {
      state.draft!.name = previous.name.isEmpty
          ? requirement.name
          : previous.name;
      state.draft!.number = previous.number;
      state.draft!.issued = previous.issuedDate;
      state.draft!.expiry =
          previous.expiryDate?.toIso8601String().substring(0, 10) ?? '';
    }
    state.operationError = state.notice = null;
    emit();
  }

  void cancel() {
    if (!state.busy) {
      state.draft = null;
      state.operationError = null;
      emit();
    }
  }

  void trace(String event) {
    _documentTrace(event);
  }

  Future<void> pick() async {
    if (!ref.mounted) return;
    if (state.busy || state.draft == null) {
      state.operationError = state.busy
          ? 'Please wait for the current document operation to finish.'
          : 'Open a document editor to choose a file.';
      emit();
      return;
    }
    state.busy = true;
    state.phase = 'Selecting file';
    state.operationError = null;
    trace('pick.start');
    emit();
    try {
      final file = await ref.read(documentPickerProvider).pick();
      if (!ref.mounted) return;
      trace(file == null ? 'pick.cancelled' : 'pick.returned');
      if (file != null) {
        if (file.validation != null) {
          state.operationError = file.validation;
        } else {
          state.draft!.file = file;
          state.draft!.upload = null;
          state.draft!.errors.remove('file');
        }
      }
    } catch (_) {
      trace('pick.failed');
      if (ref.mounted) {
        state.operationError = 'Unable to select the file. Please retry.';
      }
    } finally {
      if (ref.mounted) {
        state.busy = false;
        state.phase = null;
        trace('pick.idle');
        emit();
      }
    }
  }

  bool dateValid(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().startsWith(value);
  }

  Future<void> submit() async {
    if (!ref.mounted) return;
    final draft = state.draft;
    if (state.busy || draft == null) {
      state.operationError = state.busy
          ? 'Please wait for the current document operation to finish.'
          : 'Open a document editor before submitting.';
      trace('submit.blocked');
      emit();
      return;
    }
    draft.errors.clear();
    if (draft.file == null) {
      draft.errors['file'] = 'Please choose a document file.';
    }
    if (draft.name.trim().isEmpty) {
      draft.errors['name'] = 'Enter the document name.';
    }
    if (!dateValid(draft.issued)) {
      draft.errors['issued'] = 'Enter a valid issued date (YYYY-MM-DD).';
    }
    if (draft.requirement.hasExpiry && !dateValid(draft.expiry)) {
      draft.errors['expiry'] = 'Enter a valid expiry date (YYYY-MM-DD).';
    }
    if (draft.errors.isNotEmpty) {
      state.operationError = draft.errors.values.join(' ');
      trace('submit.validation');
      emit();
      return;
    }
    state.busy = true;
    state.phase = 'Preparing document';
    state.operationError = null;
    state.notice = null;
    trace('submit.start');
    emit();
    try {
      final repo = ref.read(documentsRepositoryProvider);
      if (draft.upload == null) {
        trace('upload.start');
        state.phase = 'Uploading document';
        state.progress = null;
        emit();
        final uploaded = await repo.upload(draft.file!, (sent, total) {
          if (ref.mounted) {
            state.progress = total > 0 ? sent / total : null;
            emit();
          }
        });
        if (!ref.mounted) return;
        if (uploaded case Success<DocumentUpload>(:final value)) {
          draft.upload = value;
          trace('upload.completed');
        } else {
          state.operationError = 'Upload failed. Please retry.';
          return;
        }
      }
      trace('register.start');
      state.phase = 'Registering document';
      emit();
      final result = await repo.register(
        DocumentRegistration(
          typeId: draft.requirement.id,
          name: draft.name.trim(),
          number: draft.number,
          key: draft.upload!.key,
          issuedDate: draft.issued,
          expiryDate: draft.requirement.hasExpiry ? draft.expiry : null,
        ),
      );
      if (!ref.mounted) return;
      if (result is! Success<void>) {
        state.operationError =
            'Registration failed. Retry will reuse your uploaded file.';
        return;
      }
      trace('register.completed');
      state.draft = null;
      state.notice =
          'Document submitted. Approval status comes from the server.';
      await refreshAfterMutation(repo);
    } catch (_) {
      if (ref.mounted) {
        state.operationError = 'Unable to submit the document. Please retry.';
      }
    } finally {
      if (ref.mounted) {
        state.busy = false;
        state.phase = null;
        trace('submit.idle');
        emit();
      }
    }
  }

  Future<void> refreshAfterMutation(DocumentsRepository repo) async {
    trace('refresh.start');
    final container = ref.container;
    container.read(providerCompletionControllerProvider.notifier).reload();
    container.invalidate(serviceSetupControllerProvider(serviceTypeId));
    state.phase = 'Refreshing documents';
    state.documentsLoading = true;
    emit();
    final result = await safe(repo.documents);
    if (!ref.mounted) return;
    state.documentsLoading = false;
    if (result case Success<List<ProviderDocument>>(:final value)) {
      state.documents = value;
      state.documentsError = null;
      trace('refresh.completed');
    } else {
      trace('refresh.failed');
      state.documentsError = 'Your change was saved, but documents could not be refreshed. Please retry refresh.';
    }
  }

  Future<void> delete(ProviderDocument document) async {
    if (state.busy || document.verificationStatus == 'APPROVED') return;
    final repo = ref.read(documentsRepositoryProvider);
    state.busy = true;
    state.phase = 'Deleting document';
    state.operationError = null;
    emit();
    try {
      final result = await repo.delete(document);
      if (!ref.mounted) return;
      if (result is Success<void>) {
        await refreshAfterMutation(repo);
      } else {
        state.operationError = 'Unable to delete this document. Please retry.';
      }
    } catch (_) {
      if (ref.mounted) {
        state.operationError = 'Unable to delete this document. Please retry.';
      }
    } finally {
      if (ref.mounted) {
        state.busy = false;
        state.phase = null;
        emit();
      }
    }
  }
}
