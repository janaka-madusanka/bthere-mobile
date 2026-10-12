import '../domain/provider_onboarding_schema.dart';

final class UnsupportedRequirementMetadata implements Exception {
  const UnsupportedRequirementMetadata();
}

Map<String, dynamic> object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

List<dynamic> array(Object? value) {
  if (value is! List) throw const FormatException('Expected array');
  return value;
}

int integer(Object? v, {bool positive = false}) {
  if (v is! int || v < (positive ? 1 : 0)) {
    throw const FormatException('Invalid integer');
  }
  return v;
}

int? optionalInt(Object? v, {bool positive = false}) =>
    v == null ? null : integer(v, positive: positive);
String string(Object? v) {
  if (v is! String || v.trim().isEmpty) {
    throw const FormatException('Invalid string');
  }
  return v;
}

bool boolean(Object? v) {
  if (v is! bool) throw const FormatException('Invalid boolean');
  return v;
}

Object? freeze(Object? v) {
  if (v is Map<String, dynamic>) {
    return Map<String, Object?>.unmodifiable(
      v.map((k, v) => MapEntry(k, freeze(v))),
    );
  }
  if (v is List) return List<Object?>.unmodifiable(v.map(freeze));
  if (v == null || v is String || v is bool || (v is num && v.isFinite)) {
    return v;
  }
  throw const FormatException('Invalid JSON');
}

ProviderLevelRequirement level(Object? raw) {
  final m = object(raw);
  final value = switch (m['level']) {
    'DISABLED' => ProviderRequirementLevel.disabled,
    'OPTIONAL' => ProviderRequirementLevel.optional,
    'REQUIRED' => ProviderRequirementLevel.required,
    _ => throw const UnsupportedRequirementMetadata(),
  };
  return ProviderLevelRequirement(value, boolean(m['requiresApproval']));
}

ProviderRequirementField field(Object? raw, int typeId, int? optionId) {
  final m = object(raw);
  if (integer(m['serviceTypeId'], positive: true) != typeId ||
      optionalInt(m['optionId'], positive: true) != optionId) {
    throw const FormatException('Mismatched field');
  }
  final min = optionalInt(m['minimumFiles']);
  final max = optionalInt(m['maximumFiles']);
  final size = m['maximumFileSizeMb'];
  if (min != null && max != null && min > max) {
    throw const FormatException('Invalid bounds');
  }
  if (size != null && (size is! num || !size.isFinite || size <= 0)) {
    throw const FormatException('Invalid size');
  }
  return ProviderRequirementField(
    fieldId: integer(m['fieldId'], positive: true),
    serviceTypeId: typeId,
    optionId: optionId,
    scope: string(m['scope']),
    code: string(m['code']),
    label: string(m['label']),
    description: m['description'] == null ? null : string(m['description']),
    fieldType: string(m['fieldType']),
    required: boolean(m['required']),
    requiresApproval: boolean(m['requiresApproval']),
    minimumFiles: min,
    maximumFiles: max,
    maximumFileSizeMb: size as num?,
    allowedFileTypes: m['allowedFileTypes'] == null
        ? []
        : array(m['allowedFileTypes']).map(string).toList(),
    options: freeze(m['options']),
    condition: freeze(m['condition']),
    displayOrder: optionalInt(m['displayOrder']),
    version: optionalInt(m['version'], positive: true),
    status: string(m['status']),
  );
}

ProviderOnboardingSchema parseProviderSchema(Object? raw, int expectedId) {
  final m = object(raw), s = object(m['serviceSetup']);
  final id = integer(m['serviceTypeId'], positive: true);
  if (id != expectedId || integer(s['serviceTypeId'], positive: true) != id) {
    throw const FormatException('Mismatched schema');
  }
  final min = optionalInt(s['minimumOptionSelections']),
      max = optionalInt(s['maximumOptionSelections']);
  if (min != null && max != null && min > max) {
    throw const FormatException('Invalid option bounds');
  }
  final options = array(m['options']).map((raw) {
    final o = object(raw), optionId = integer(o['optionId'], positive: true);
    return ProviderSchemaOption(
      optionId: optionId,
      code: string(o['code']),
      name: string(o['name']),
      fields: array(o['fields']).map((v) => field(v, id, optionId)).toList(),
    );
  }).toList();
  if (options.map((o) => o.optionId).toSet().length != options.length) {
    throw const FormatException('Duplicate options');
  }
  return ProviderOnboardingSchema(
    serviceTypeId: id,
    serviceName: string(m['serviceName']),
    serviceSetup: ProviderServiceSetup(
      serviceTypeId: id,
      name: string(s['name']),
      availabilityEnabled: boolean(s['availabilityEnabled']),
      serviceAreasEnabled: boolean(s['serviceAreasEnabled']),
      optionsRequired: boolean(s['optionsRequired']),
      minimumOptionSelections: min,
      maximumOptionSelections: max,
      documents: array(s['documents'])
          .map(
            (v) => ProviderDocumentRequirement(
              freeze(object(v)) as Map<String, Object?>,
            ),
          )
          .toList(),
      skills: array(s['skills'])
          .map(
            (v) => ProviderSkillRequirement(
              freeze(object(v)) as Map<String, Object?>,
            ),
          )
          .toList(),
      certificates: level(s['certificates']),
      education: level(s['education']),
    ),
    commonFields: array(m['commonFields'])
        .map((v) => field(v, id, null))
        .toList(),
    options: options,
  );
}
