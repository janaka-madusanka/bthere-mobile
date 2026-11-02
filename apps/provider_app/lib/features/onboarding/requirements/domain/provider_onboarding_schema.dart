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
    this.displayOrder = 0,
    this.defaultCapacity,
    this.bookingMode,
  }) : fields = List.unmodifiable(fields);
  final int optionId;
  final String code, name;
  final String? description;
  final ProviderServiceMedia? icon;
  final List<String> deliveryModes;
  final bool locationEnabled;
  final int displayOrder;
  final int? defaultCapacity;
  final String? bookingMode;

  /// All configured groups are retained. A legacy saved mode only fills missing
  /// metadata; it never overrides explicit service configuration.
  List<String> configuredLocationModes([Object? saved]) {
    const supported = {
      'PROVIDER_TO_CUSTOMER',
      'CUSTOMER_TO_PROVIDER',
      'ONLINE',
    };
    if (deliveryModes.isNotEmpty) {
      if (deliveryModes.any((mode) => !supported.contains(mode))) {
        return const [];
      }
      return deliveryModes.toSet().toList();
    }
    return saved is String && supported.contains(saved) ? [saved] : const [];
  }

  String? configuredLocationMode([Object? saved]) {
    final modes = configuredLocationModes(saved);
    if (modes.length == 1) return modes.single;
    return saved is String && modes.contains(saved) ? saved : null;
  }

  /// New drafts keep independent areas per configured mode. Legacy single-mode
  /// drafts remain readable without copying premises into travel coverage.
  Map<String, Map<String, dynamic>> locationGroups(Map data) {
    final saved = data['deliveryMode'];
    final modes = configuredLocationModes(saved);
    final grouped = data['locationsByMode'] as Map? ?? {};
    return {
      for (final mode in modes.where((mode) => mode != 'ONLINE'))
        mode: grouped[mode] is Map
            ? Map<String, dynamic>.from(grouped[mode] as Map)
            : {
                'areas': saved == mode || (saved == null && modes.length == 1)
                    ? data['areas'] as List? ?? []
                    : [],
              },
    };
  }

  String? validateLocations(Map data) {
    final modes = configuredLocationModes(data['deliveryMode']);
    if (modes.isEmpty) {
      return 'This service is missing supported location configuration. Please reload the service.';
    }
    final groups = locationGroups(data);
    for (final entry in groups.entries) {
      final areas = entry.value['areas'] as List? ?? [];
      if (areas.isEmpty) {
        return 'Add a location for each configured service location group.';
      }
      for (final area in areas) {
        if (area is! Map) return 'Check the service location details.';
        final lat = area['latitude'],
            lng = area['longitude'],
            radius = area['radiusKm'],
            capacity = area['capacity'];
        if (lat is! num ||
            !lat.isFinite ||
            lat.abs() > 90 ||
            lng is! num ||
            !lng.isFinite ||
            lng.abs() > 180) {
          return 'Select a valid map location for each service location.';
        }
        if (entry.key == 'PROVIDER_TO_CUSTOMER' &&
            (radius is! num || !radius.isFinite || radius <= 0)) {
          return 'Enter a positive radius for each customer coverage area.';
        }
        if (capacity != null && (capacity is! int || capacity <= 0)) {
          return 'Enter a positive whole number for location capacity.';
        }
      }
    }
    return null;
  }

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
