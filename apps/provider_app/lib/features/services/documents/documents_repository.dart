import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/foundation.dart';

import '../../onboarding/requirements/data/provider_schema_response.dart'
    as json;
import 'document_models.dart';

String? optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid text');
  return value.trim().isEmpty ? null : value;
}

DateTime dateOnly(Object? raw) {
  final value = json.string(raw);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid date');
  }
  final date = DateTime.tryParse(value);
  if (date == null || !date.toIso8601String().startsWith(value)) {
    throw const FormatException('Invalid date');
  }
  return DateTime.utc(date.year, date.month, date.day);
}

List<DocumentRequirement> parseRequirements(Object? data) {
  final ids = <String>{};
  return List.unmodifiable(
    json.array(data).map((item) {
      final m = json.object(item);
      final id = json.integer(m['documentTypeId'], positive: true);
      final optionId = json.optionalInt(m['optionId'], positive: true);
      if (!ids.add('$id:${optionId ?? 'common'}')) {
        throw const FormatException('Duplicate document requirement');
      }
      final issuedMode = m['issuedDateMode'] == null
          ? 'OPTIONAL'
          : json.string(m['issuedDateMode']);
      final expiryMode = m['expiryDateMode'] == null
          ? null
          : json.string(m['expiryDateMode']);
      if (!const {'HIDDEN', 'OPTIONAL', 'REQUIRED'}.contains(issuedMode) ||
          (expiryMode != null &&
              !const {'HIDDEN', 'OPTIONAL', 'REQUIRED'}.contains(expiryMode))) {
        throw const FormatException('Invalid document date mode');
      }
      final parts = (m['parts'] == null ? const <dynamic>[] : json.array(m['parts']))
          .map((raw) {
            final part = json.object(raw);
            final maxFiles = json.integer(part['maximumFiles'], positive: true);
            final maxSize = json.integer(part['maximumFileSizeMb'], positive: true);
            if (maxFiles > 100 || maxSize > 100) {
              throw const FormatException('Invalid document part limits');
            }
            return DocumentPartDefinition(
              code: json.string(part['code']),
              label: json.string(part['label']),
              required: json.boolean(part['required']),
              maximumFiles: maxFiles,
              maximumFileSizeMb: maxSize,
              allowedFileTypes: part['allowedFileTypes'] == null
                  ? const []
                  : List.unmodifiable(json.array(part['allowedFileTypes']).map(json.string)),
            );
          })
          .toList();
      if (parts.map((part) => part.code).toSet().length != parts.length) {
        throw const FormatException('Duplicate document part');
      }
      return DocumentRequirement(
        id,
        json.string(m['documentTypeName']),
        optionalText(m['description']),
        json.boolean(m['hasExpiry']),
        json.boolean(m['required']),
        json.boolean(m['requiresApproval']),
        optionId: optionId,
        issuedDateMode: issuedMode,
        expiryDateMode: expiryMode,
        parts: List.unmodifiable(parts),
      );
    }),
  );
}

List<ProviderDocumentTypeDefinition> parseDocumentTypes(Object? data) =>
    List.unmodifiable(json.array(data).map((raw) {
      final item = json.object(raw);
      final id = json.integer(item['id'], positive: true);
      final issued = json.string(item['issuedDateMode']);
      final expiry = json.string(item['expiryDateMode']);
      if (!const {'HIDDEN', 'OPTIONAL', 'REQUIRED'}.contains(issued) ||
          !const {'HIDDEN', 'OPTIONAL', 'REQUIRED'}.contains(expiry)) {
        throw const FormatException('Invalid document date mode');
      }
      final parts = parseRequirements([
        {
          'documentTypeId': id,
          'documentTypeName': json.string(item['name']),
          'hasExpiry': expiry != 'HIDDEN',
          'required': false,
          'requiresApproval': false,
          'issuedDateMode': issued,
          'expiryDateMode': expiry,
          'parts': item['parts'] ?? const [],
        },
      ]).single.parts;
      return ProviderDocumentTypeDefinition(
        id: id,
        name: json.string(item['name']),
        issuedDateMode: issued,
        expiryDateMode: expiry,
        parts: parts,
      );
    }));

List<DocumentRequirement> applyDocumentTypeDefinitions(
  List<DocumentRequirement> requirements,
  List<ProviderDocumentTypeDefinition> definitions,
) {
  final byId = {for (final definition in definitions) definition.id: definition};
  return List.unmodifiable(requirements.map((requirement) {
    final definition = byId[requirement.id];
    if (definition == null) return requirement;
    return DocumentRequirement(
      requirement.id,
      requirement.name,
      requirement.description,
      definition.expiryDateMode != 'HIDDEN',
      requirement.required,
      requirement.requiresApproval,
      optionId: requirement.optionId,
      issuedDateMode: definition.issuedDateMode,
      expiryDateMode: definition.expiryDateMode,
      parts: definition.parts,
    );
  }));
}

List<ProviderDocument> parseDocuments(Object? data) {
  final ids = <int>{};
  return List.unmodifiable(
    json.schemaValue('documents', () => json.array(data)).indexed.map((entry) {
      final m = json.schemaValue(
        'documents[${entry.$1}]',
        () => json.object(entry.$2),
      );
      T read<T>(String key, T Function(Object?) parse) =>
          json.schemaValue('documents[${entry.$1}].$key', () => parse(m[key]));
      final id = read('documentId', (v) => json.integer(v, positive: true));
      if (!ids.add(id)) throw const FormatException('Duplicate document');
      final date = read('expiryDate', (v) => v == null ? null : dateOnly(v));
      List<Map<String, Object?>> maps(String key) {
        final raw = m[key];
        if (raw == null) return const [];
        return List.unmodifiable(
          json.array(raw).map((item) => Map<String, Object?>.unmodifiable(json.object(item))),
        );
      }
      return ProviderDocument(
        id,
        read('documentTypeId', (v) => json.integer(v, positive: true)),
        read('verificationStatus', json.string),
        read('rejectionReason', optionalText),
        date,
        typeName: read('documentTypeName', json.string),
        name: read('documentName', json.string),
        number: read(
          'documentNumber',
          (v) => v == null
              ? ''
              : v is String
              ? v
              : throw const FormatException('Invalid document number'),
        ),
        key: read('documentKey', json.string),
        // Uploads omit these optional values when they are not applicable
        // (for example a selfie). Read-back must accept the same contract.
        issuedDate: read(
          'issuedDate',
          (v) => v == null || v == ''
              ? ''
              : dateOnly(v).toIso8601String().substring(0, 10),
        ),
        createdAt: read(
          'createdAt',
          (v) =>
              DateTime.tryParse(json.string(v)) ??
              (throw const FormatException('Invalid created date')),
        ),
        parts: maps('parts'),
        partDefinitions: maps('partDefinitions'),
      );
    }),
  );
}

DocumentUpload parseUpload(Object? data) {
  final m = json.object(data);
  return DocumentUpload(
    json.string(m['key']),
    json.string(m['url']),
    json.string(m['contentType']),
    json.integer(m['size'], positive: true),
  );
}

class ApiDocumentsRepository implements DocumentsRepository {
  const ApiDocumentsRepository(this.client, {this.diagnosticLogger});
  final ApiClient client;
  final void Function(String)? diagnosticLogger;
  void _diagnostic(String message) {
    if (diagnosticLogger != null)
      diagnosticLogger!(message);
    else if (kDebugMode)
      debugPrint(message);
  }

  Future<Result<T>> request<T>(
    Future<T> Function() operation, {
    String resource = 'request',
  }) async {
    try {
      return Success(await operation());
    } on NetworkException catch (e) {
      _diagnostic(
        '[ProviderDocuments] resource=$resource outcome=${e.kind.name} status=${e.statusCode}',
      );
      return Failure(e.toAppFailure());
    } catch (error) {
      _diagnostic(
        '[ProviderDocuments] resource=$resource outcome=invalid-response exception=${error.runtimeType}${error is json.InvalidSchemaValue ? ' invalidPath=${error.path}' : ''}',
      );
      return const Failure(
        AppFailure(
          message: 'Unable to complete the document request. Please retry.',
        ),
      );
    }
  }

  @override
  Future<Result<List<DocumentRequirement>>> requirements(int serviceTypeId) =>
      request(() async {
        if (serviceTypeId <= 0) throw const FormatException('Invalid service');
        return parseRequirements(
          (await client.get<Object?>(
            '/provider-types/$serviceTypeId/document-requirements',
            requiresAuth: true,
          )).data,
        );
      }, resource: 'document-requirements');
  @override
  Future<Result<List<ProviderDocumentTypeDefinition>>> documentTypes() =>
      request(
        () async => parseDocumentTypes(
          (await client.get<Object?>(
            '/document-types',
            requiresAuth: true,
          )).data,
        ),
        resource: 'document-types',
      );
  @override
  Future<Result<List<ProviderDocument>>> documents() => request(
    () async => parseDocuments(
      (await client.get<Object?>(
        '/providers/me/documents',
        requiresAuth: true,
      )).data,
    ),
    resource: 'documents',
  );
  @override
  Future<Result<Uri>> viewUrl(String key) => request(() async {
    if (key.trim().isEmpty) throw const FormatException('Invalid file key');
    final path = Uri(
      path: '/uploads/view-url',
      queryParameters: {'key': key},
    ).toString();
    final data = (await client.get<Object?>(path, requiresAuth: true)).data;
    final raw = data is String
        ? data
        : data is Map && data['url'] is String
        ? data['url'] as String
        : throw const FormatException('Invalid viewing URL');
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid viewing URL');
    }
    return uri;
  });
  @override
  Future<Result<DocumentUpload>> upload(
    DocumentFile file,
    void Function(int, int) progress,
  ) => request(() async {
    if (file.validation != null) throw const FormatException('Invalid file');
    final form = FormData.fromMap({
      'file': MultipartFile.fromStream(
        file.openRead,
        file.size,
        filename: file.name,
      ),
    });
    return parseUpload(
      (await client.upload<Object?>(
        '/uploads/documents',
        data: form,
        onSendProgress: progress,
        requiresAuth: true,
      )).data,
    );
  });
  @override
  Future<Result<void>> register(DocumentRegistration input) =>
      request(() async {
        await client.post<Object?>(
          '/providers/me/documents',
          data: input.toJson(),
          requiresAuth: true,
        );
      });
  @override
  Future<Result<void>> delete(ProviderDocument document) => request(() async {
    if (document.verificationStatus == 'APPROVED' || document.id <= 0) {
      throw const FormatException('Document cannot be deleted');
    }
    await client.delete<Object?>(
      '/providers/me/documents/${document.id}',
      requiresAuth: true,
    );
  });
}
