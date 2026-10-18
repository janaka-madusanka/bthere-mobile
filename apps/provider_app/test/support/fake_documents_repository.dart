import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/services/documents/document_models.dart';
import 'package:provider_app/features/services/documents/documents_repository.dart';
import 'package:provider_app/features/services/documents/documents_controller.dart';

Map<String, Object?> requirementJson({
  int id = 1,
  bool required = true,
  bool expiry = false,
  bool approval = true,
}) => {
  'documentTypeId': id,
  'documentTypeName': id == 1 ? 'National ID' : 'Licence',
  'description': 'Government identity document',
  'hasExpiry': expiry,
  'required': required,
  'requiresApproval': approval,
};
Map<String, Object?> documentJson({
  String status = 'PENDING',
  String? expiry,
}) => {
  'documentId': 70,
  'serviceProviderId': 12,
  'documentTypeId': 1,
  'documentTypeName': 'National ID',
  'documentName': 'National Identity Card',
  'documentNumber': '200012345678',
  'documentKey': 'providers/25/documents/uuid.pdf',
  'issuedDate': '2020-01-01',
  'expiryDate': expiry,
  'verificationStatus': status,
  'verifiedBy': null,
  'verifiedAt': null,
  'rejectionReason': status == 'REJECTED' ? 'Unreadable scan' : null,
  'createdAt': '2026-10-09T10:00:00',
};
DocumentFile file({String name = 'scan.pdf', int size = 3}) =>
    DocumentFile(name, size, () => Stream.value([1, 2, 3]));
final requirement = parseRequirements([requirementJson()]).single;

class FakeDocuments implements DocumentsRepository {
  Result<List<DocumentRequirement>> requirementsResult = Success([requirement]);
  Result<List<ProviderDocument>> documentsResult = const Success([]);
  Result<void> registerResult = const Success(null),
      deleteResult = const Success(null);
  Result<DocumentUpload> uploadResult = const Success(
    DocumentUpload(
      'upload-key',
      'https://example.invalid/scan.pdf',
      'application/pdf',
      3,
    ),
  );
  int requirementCalls = 0, documentCalls = 0, uploads = 0, deletes = 0;
  int viewUrlCalls = 0;
  final registrations = <DocumentRegistration>[];
  Completer<Result<void>>? pending;
  Completer<Result<List<DocumentRequirement>>>? pendingRequirements;
  Completer<Result<List<ProviderDocument>>>? pendingDocuments;
  @override
  Future<Result<List<DocumentRequirement>>> requirements(int id) async {
    requirementCalls++;
    return pendingRequirements?.future ?? requirementsResult;
  }

  @override
  Future<Result<List<ProviderDocument>>> documents() async {
    documentCalls++;
    return pendingDocuments?.future ?? documentsResult;
  }

  @override
  Future<Result<Uri>> viewUrl(String key) async {
    viewUrlCalls++;
    return Success(Uri.parse('https://example.invalid/view'));
  }

  @override
  Future<Result<DocumentUpload>> upload(
    DocumentFile file,
    void Function(int, int) progress,
  ) async {
    uploads++;
    progress(3, 3);
    return uploadResult;
  }

  @override
  Future<Result<void>> register(DocumentRegistration input) async {
    registrations.add(input);
    return pending?.future ?? registerResult;
  }

  @override
  Future<Result<void>> delete(ProviderDocument document) async {
    deletes++;
    return deleteResult;
  }
}

class FakePicker implements DocumentPicker {
  DocumentFile? selected = file();
  bool throws = false;
  int calls = 0;
  Completer<DocumentFile?>? pending;
  @override
  Future<DocumentFile?> pick() async {
    calls++;
    if (throws) throw StateError('private file path');
    return pending?.future ?? selected;
  }
}
