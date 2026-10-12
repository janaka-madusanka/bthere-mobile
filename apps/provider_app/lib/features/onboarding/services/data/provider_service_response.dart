import '../domain/provider_service_type.dart';
import '../domain/provider_service_assignment.dart';

List<ProviderServiceType> parseActiveProviderServices(Object? value) {
  if (value is! List) throw const FormatException('Invalid services');
  final seen = <int>{};
  final services = <ProviderServiceType>[];
  for (final item in value) {
    final json = _object(item);
    final id = _id(json['id']);
    if (!seen.add(id)) throw const FormatException('Duplicate service ID');
    final service = ProviderServiceType(
      id: id,
      name: _text(json['name']),
      description: _optionalText(json['description']),
      iconUrl: _optionalText(json['iconUrl']),
      status: _text(json['status']),
    );
    if (service.status == 'ACTIVE') services.add(service);
  }
  return List.unmodifiable(services);
}

ProviderServiceAssignment parseProviderServiceAssignment(Object? value) {
  final json = _object(value);
  final years = json['experienceYears'];
  if (years is! num || !years.isFinite || years < 0) {
    throw const FormatException('Invalid experience');
  }
  final override = json['emergencyOverride'];
  if (override is! bool) throw const FormatException('Invalid override');
  final expiryValue = _optionalText(json['emergencyOverrideExpiresAt']);
  final expiry = expiryValue == null ? null : DateTime.tryParse(expiryValue);
  if (expiryValue != null && expiry == null) {
    throw const FormatException('Invalid expiry');
  }
  return ProviderServiceAssignment(
    assignmentId: _id(json['assignmentId']),
    providerTypeId: _id(json['providerTypeId']),
    providerTypeName: _text(json['providerTypeName']),
    experienceYears: years,
    status: _text(json['status']),
    providerStatus: _text(json['providerStatus']),
    adminStatus: _text(json['adminStatus']),
    verificationStatus: _text(json['verificationStatus']),
    emergencyOverride: override,
    rejectionReason: _optionalText(json['rejectionReason']),
    emergencyOverrideReason: _optionalText(json['emergencyOverrideReason']),
    emergencyOverrideExpiresAt: expiry?.toUtc(),
    requiredDocumentTypeIds: _ids(json['requiredDocumentTypeIds']),
    missingDocumentTypeIds: _ids(json['missingDocumentTypeIds']),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid object');
  }
  return value;
}

int _id(Object? value) {
  if (value is! int || value <= 0) throw const FormatException('Invalid ID');
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid text');
  }
  return value.trim();
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Invalid optional text');
  return value.trim().isEmpty ? null : value.trim();
}

List<int> _ids(Object? value) {
  if (value is! List) throw const FormatException('Invalid document IDs');
  return value.map(_id).toList();
}

List<ProviderServiceAssignment> parseProviderServiceAssignments(Object? value) {
  if (value is! List) throw const FormatException('Invalid assignments');
  final values = value.map(parseProviderServiceAssignment).toList();
  if (values.map((a) => a.assignmentId).toSet().length != values.length ||
      values.map((a) => a.providerTypeId).toSet().length != values.length) {
    throw const FormatException('Ambiguous service assignments');
  }
  return List.unmodifiable(values);
}
