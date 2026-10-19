import '../../services/domain/provider_service_type.dart';

Object? immutableSchemaJson(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, value) => MapEntry(key, immutableSchemaJson(value))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(immutableSchemaJson));
  }
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const FormatException('Invalid JSON metadata');
}

enum ProviderRequirementLevel { disabled, optional, required }

final class ProviderLevelRequirement {
  const ProviderLevelRequirement(this.level, this.requiresApproval);
  final ProviderRequirementLevel level;
  final bool requiresApproval;
}

/// Opaque JSON metadata: the supplied contract does not define inner fields.
final class ProviderDocumentRequirement {
  ProviderDocumentRequirement(Map<String, Object?> metadata)
    : metadata = immutableSchemaJson(metadata) as Map<String, Object?>;
  final Map<String, Object?> metadata;
}

final class ProviderSkillRequirement {
  ProviderSkillRequirement(Map<String, Object?> metadata)
    : metadata = immutableSchemaJson(metadata) as Map<String, Object?>;
  final Map<String, Object?> metadata;
}

final class ProviderRequirementField {
  ProviderRequirementField({
    required this.fieldId,
    required this.serviceTypeId,
    required this.optionId,
    required List<int> optionIds,
    required this.reuseScope,
    required this.scope,
    required this.code,
    required this.label,
    required this.description,
    required this.fieldType,
    required this.required,
    required this.requiresApproval,
    required this.minimumFiles,
    required this.maximumFiles,
    required this.maximumFileSizeMb,
    required List<String> allowedFileTypes,
    required Object? options,
    required Object? condition,
    required this.displayOrder,
    required this.version,
    required this.status,
  }) : optionIds = List.unmodifiable(optionIds),
       allowedFileTypes = List.unmodifiable(allowedFileTypes),
       options = immutableSchemaJson(options),
       condition = immutableSchemaJson(condition);
  final int fieldId, serviceTypeId;
  final int? optionId, minimumFiles, maximumFiles, displayOrder, version;
  final List<int> optionIds;
  final String scope, reuseScope, code, label, fieldType, status;
  final String? description;
  final bool required, requiresApproval;
  final num? maximumFileSizeMb;
  final List<String> allowedFileTypes;
  final Object? options, condition;
}

final class ProviderSchemaOption {
  ProviderSchemaOption({
    required this.optionId,
    required this.code,
    required this.name,
    required List<ProviderRequirementField> fields,
    this.description,
    this.icon,
    this.deliveryModes = const [],
    this.locationEnabled = true,
    this.defaultCapacity,
    this.bookingMode,
  }) : fields = List.unmodifiable(fields);
  final int optionId;
  final String code, name;
  final String? description;
  final ProviderServiceMedia? icon;
  final List<String> deliveryModes;
  final bool locationEnabled;
  final int? defaultCapacity;
  final String? bookingMode;

  bool usesServiceAreas(ProviderServiceSetup setup) =>
      setup.serviceAreasEnabled && locationEnabled;
  final List<ProviderRequirementField> fields;
}

final class ProviderServiceSetup {
  ProviderServiceSetup({
    required this.serviceTypeId,
    required this.name,
    required this.availabilityEnabled,
    required this.serviceAreasEnabled,
    required this.optionsRequired,
    required this.minimumOptionSelections,
    required this.maximumOptionSelections,
    required List<ProviderDocumentRequirement> documents,
    required List<ProviderSkillRequirement> skills,
    required this.certificates,
    required this.education,
  }) : documents = List.unmodifiable(documents),
       skills = List.unmodifiable(skills);
  final int serviceTypeId;
  final String name;
  final bool availabilityEnabled, serviceAreasEnabled, optionsRequired;
  final int? minimumOptionSelections, maximumOptionSelections;
  final List<ProviderDocumentRequirement> documents;
  final List<ProviderSkillRequirement> skills;
  final ProviderLevelRequirement certificates, education;
}

final class ProviderOnboardingSchema {
  ProviderOnboardingSchema({
    required this.serviceTypeId,
    required this.serviceName,
    required this.serviceSetup,
    required List<ProviderRequirementField> commonFields,
    required List<ProviderSchemaOption> options,
  }) : commonFields = List.unmodifiable(commonFields),
       options = List.unmodifiable(options);
  final int serviceTypeId;
  final String serviceName;
  final ProviderServiceSetup serviceSetup;
  final List<ProviderRequirementField> commonFields;
  final List<ProviderSchemaOption> options;
}
