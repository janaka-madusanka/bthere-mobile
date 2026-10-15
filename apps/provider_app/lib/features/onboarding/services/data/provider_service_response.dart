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
      icon: _media(json['icon']),
      coverImage: _media(json['coverImage']),
      gallery: _mediaList(json['gallery']),
      responsibilities: _responsibilities(json['responsibilities']),
      status: _text(json['status']),
    );
    if (service.status == 'ACTIVE') services.add(service);
  }
  return List.unmodifiable(services);
}

ProviderServiceMedia? parseProviderServiceMedia(Object? value) => _media(value);

ProviderServiceMedia? _media(Object? value) {
  if (value == null) return null;
  final json = _object(value);
  return ProviderServiceMedia(
    key: _text(json['key']),
    url: _text(json['url']),
    altText: _optionalText(json['altText']),
    displayOrder: json['displayOrder'] == null
        ? 0
        : _nonNegative(json['displayOrder']),
  );
}

int _nonNegative(Object? value) {
  if (value is! int || value < 0) throw const FormatException('Invalid order');
  return value;
}

List<ProviderServiceMedia> _mediaList(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Invalid media');
  final result = value.map(_media).whereType<ProviderServiceMedia>().toList()
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return List.unmodifiable(result);
}

List<ProviderServiceResponsibility> _responsibilities(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Invalid responsibilities');
  final result = value.map((item) {
    final json = _object(item);
    final party = _text(json['responsibleParty']);
    if (!['PROVIDER', 'CUSTOMER', 'PLATFORM'].contains(party) ||
        json['required'] is! bool) {
      throw const FormatException('Invalid responsibility');
    }
    return ProviderServiceResponsibility(
      responsibleParty: party,
      title: _text(json['title']),
      description: _optionalText(json['description']),
      required: json['required'] as bool,
      displayOrder: _nonNegative(json['displayOrder']),
    );
  }).toList()..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return List.unmodifiable(result);
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
