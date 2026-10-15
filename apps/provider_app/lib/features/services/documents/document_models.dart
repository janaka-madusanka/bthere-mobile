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
  });
  final int id;
  final String name;
  final String? description;
  final bool hasExpiry, required, requiresApproval;
  final int? optionId;
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
  });
  final int id, typeId;
  final String typeName, name, number, key, issuedDate;
  final DateTime? createdAt;
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
  });
  final int typeId;
  final String name, number, key, issuedDate;
  final String? expiryDate;
  Map<String, Object?> toJson() => {
    'documentTypeId': typeId,
    'documentName': name,
    'documentNumber': number,
    'documentKey': key,
    'issuedDate': issuedDate,
    'expiryDate': expiryDate,
  };
}

abstract interface class DocumentsRepository {
  Future<Result<List<DocumentRequirement>>> requirements(int serviceTypeId);
  Future<Result<List<ProviderDocument>>> documents();
  Future<Result<Uri>> viewUrl(String key);
  Future<Result<DocumentUpload>> upload(
    DocumentFile file,
    void Function(int, int) progress,
  );
  Future<Result<void>> register(DocumentRegistration input);
  Future<Result<void>> delete(ProviderDocument document);
}
