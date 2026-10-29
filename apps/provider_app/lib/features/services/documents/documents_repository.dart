import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';

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
      return DocumentRequirement(
        id,
        json.string(m['documentTypeName']),
        optionalText(m['description']),
        json.boolean(m['hasExpiry']),
        json.boolean(m['required']),
        json.boolean(m['requiresApproval']),
        optionId: optionId,
      );
    }),
  );
}

List<ProviderDocument> parseDocuments(Object? data) {
  final ids = <int>{};
  return List.unmodifiable(
    json.array(data).map((item) {
      final m = json.object(item);
      final id = json.integer(m['documentId'], positive: true);
      if (!ids.add(id)) throw const FormatException('Duplicate document');
      final date = m['expiryDate'] == null ? null : dateOnly(m['expiryDate']);
      return ProviderDocument(
        id,
        json.integer(m['documentTypeId'], positive: true),
        json.string(m['verificationStatus']),
        optionalText(m['rejectionReason']),
        date,
        typeName: json.string(m['documentTypeName']),
        name: json.string(m['documentName']),
        number: m['documentNumber'] is String
            ? m['documentNumber'] as String
            : throw const FormatException('Invalid document number'),
        key: json.string(m['documentKey']),
        issuedDate: dateOnly(m['issuedDate'])
            .toIso8601String()
            .substring(0, 10),
        createdAt:
            DateTime.tryParse(json.string(m['createdAt'])) ??
            (throw const FormatException('Invalid created date')),
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
  const ApiDocumentsRepository(this.client);
  final ApiClient client;
  Future<Result<T>> request<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on NetworkException catch (e) {
      return Failure(e.toAppFailure());
    } catch (_) {
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
      });
  @override
  Future<Result<List<ProviderDocument>>> documents() => request(
    () async => parseDocuments(
      (await client.get<Object?>(
        '/providers/me/documents',
        requiresAuth: true,
      )).data,
    ),
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
