import 'package:bthere_common/bthere_common.dart';

const documentExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];
const maximumDocumentBytes = 100000000;

class DocumentRequirement {
  const DocumentRequirement(
    this.id,
    this.name,
    this.description,
    this.hasExpiry,
    this.required,
    this.requiresApproval, {
    this.optionId,
    this.issuedDateMode = 'OPTIONAL',
    this.expiryDateMode,
    this.parts = const [],
  });
  final int id;
  final String name;
  final String? description;
  final bool hasExpiry, required, requiresApproval;
  final int? optionId;
  final String issuedDateMode;
  final String? expiryDateMode;
  final List<DocumentPartDefinition> parts;
  bool get issuedDateRequired => issuedDateMode == 'REQUIRED';
  bool get issuedDateVisible => issuedDateMode != 'HIDDEN';
  bool get expiryDateRequired => expiryDateMode == 'REQUIRED';
  bool get expiryDateVisible =>
      expiryDateMode == null ? hasExpiry : expiryDateMode != 'HIDDEN';
  bool get isSelfie =>
      RegExp(r'self[ -]?ie', caseSensitive: false).hasMatch(name);
}

class ProviderDocumentTypeDefinition {
  const ProviderDocumentTypeDefinition({
    required this.id,
    required this.name,
    required this.issuedDateMode,
    required this.expiryDateMode,
    required this.parts,
  });
  final int id;
  final String name, issuedDateMode, expiryDateMode;
  final List<DocumentPartDefinition> parts;
}

class DocumentPartDefinition {
  const DocumentPartDefinition({
    required this.code,
    required this.label,
    required this.required,
    required this.maximumFiles,
    required this.maximumFileSizeMb,
    required this.allowedFileTypes,
  });
  final String code, label;
  final bool required;
  final int maximumFiles, maximumFileSizeMb;
  final List<String> allowedFileTypes;
}

class ProviderDocument {
  const ProviderDocument(
    this.id,
    this.typeId,
    this.verificationStatus,
    this.rejectionReason,
    this.expiryDate, {
    this.typeName = '',
    this.name = '',
    this.number = '',
    this.key = '',
    this.issuedDate = '',
    this.createdAt,
    this.parts = const [],
    this.partDefinitions = const [],
  });
  final int id, typeId;
  final String typeName, name, number, key, issuedDate;
  final DateTime? createdAt;
  final List<Map<String, Object?>> parts, partDefinitions;
  final String verificationStatus;
  final String? rejectionReason;
  final DateTime? expiryDate;
  String status(DateTime now) {
    if (expiryDate != null &&
        DateTime.utc(
          expiryDate!.year,
          expiryDate!.month,
          expiryDate!.day,
        ).isBefore(DateTime.utc(now.year, now.month, now.day))) {
      return 'Expired';
    }
    return switch (verificationStatus) {
      'APPROVED' => 'Approved',
      'PENDING' => 'Pending approval',
      'REJECTED' => 'Rejected',
      _ => 'Status unavailable',
    };
  }
}

class DocumentFile {
  const DocumentFile(this.name, this.size, this.openRead);
  final String name;
  final int size;
  final Stream<List<int>> Function() openRead;
  String? get validation {
    if (!documentExtensions.contains(name.split('.').last.toLowerCase())) {
      return 'Choose a PDF, JPG, JPEG, PNG or WebP file.';
    }
    if (size <= 0 || size > maximumDocumentBytes) {
      return 'Choose a file up to 100 MB.';
    }
    return null;
  }
}

class DocumentUpload {
  const DocumentUpload(this.key, this.url, this.contentType, this.size);
  final String key, url, contentType;
  final int size;
}

class DocumentRegistration {
  const DocumentRegistration({
    required this.typeId,
    required this.name,
    required this.number,
    required this.key,
    required this.issuedDate,
    required this.expiryDate,
    this.parts = const [],
  });
  final int typeId;
  final String name, number, key, issuedDate;
  final String? expiryDate;
  final List<Map<String, Object?>> parts;
  Map<String, Object?> toJson() => {
    'documentTypeId': typeId,
    'documentName': name,
    if (number.trim().isNotEmpty) 'documentNumber': number,
    if (parts.isEmpty) 'documentKey': key,
    if (parts.isNotEmpty) 'parts': parts,
    if (issuedDate.isNotEmpty) 'issuedDate': issuedDate,
    if (expiryDate != null && expiryDate!.isNotEmpty) 'expiryDate': expiryDate,
  };
}

abstract interface class DocumentsRepository {
  Future<Result<List<DocumentRequirement>>> requirements(int serviceTypeId);
  Future<Result<List<ProviderDocumentTypeDefinition>>> documentTypes();
  Future<Result<List<ProviderDocument>>> documents();
  Future<Result<Uri>> viewUrl(String key);
  Future<Result<DocumentUpload>> upload(
    DocumentFile file,
    void Function(int, int) progress,
  );
  Future<Result<void>> register(DocumentRegistration input);
  Future<Result<void>> delete(ProviderDocument document);
}
