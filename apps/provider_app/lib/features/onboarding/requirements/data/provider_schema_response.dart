import '../../services/data/provider_service_response.dart'
    show parseProviderServiceMedia;
import '../domain/provider_onboarding_schema.dart';

final class UnsupportedRequirementMetadata implements Exception {
  const UnsupportedRequirementMetadata();
}

/// Static schema paths only: no response values or personal data in diagnostics.
final class InvalidSchemaValue extends FormatException {
  const InvalidSchemaValue(this.path) : super('Invalid onboarding schema');
  final String path;
}

T schemaValue<T>(String path, T Function() read) {
  try {
    return read();
  } on InvalidSchemaValue catch (error) {
    throw InvalidSchemaValue('$path.${error.path}');
  } on FormatException {
    throw InvalidSchemaValue(path);
  } on TypeError {
    throw InvalidSchemaValue(path);
  }
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

ProviderRequirementField field(
  Object? raw,
  int? typeId,
  int? containerOptionId,
) {
  final m = object(raw);
  final legacyOptionId = optionalInt(m['optionId'], positive: true);
  final optionIds = m['optionIds'] == null
      ? <int>[?legacyOptionId]
      : array(m['optionIds']).map((v) => integer(v, positive: true)).toList();
  final serviceTypeId = schemaValue(
    'serviceTypeId',
    () => integer(m['serviceTypeId'], positive: true),
  );
  final configurationId =
      optionalInt(m['configurationServiceTypeId'], positive: true) ?? typeId;
  if (configurationId != null && serviceTypeId != configurationId) {
    throw const InvalidSchemaValue('serviceTypeId');
  }
  if (optionIds.toSet().length != optionIds.length ||
      (legacyOptionId != null &&
          m['optionIds'] != null &&
          !optionIds.contains(legacyOptionId)) ||
      (containerOptionId == null && optionIds.isNotEmpty) ||
      (containerOptionId != null && !optionIds.contains(containerOptionId))) {
    throw const InvalidSchemaValue('optionIds');
  }
  final reuseScope = m['reuseScope'] == null
      ? 'ASSIGNMENT'
      : string(m['reuseScope']);
  if (!['ASSIGNMENT', 'SERVICE', 'PROVIDER'].contains(reuseScope)) {
    throw const FormatException('Invalid reuse scope');
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
    fieldId: schemaValue(
      'fieldId',
      () => integer(m['fieldId'], positive: true),
    ),
    serviceTypeId: serviceTypeId,
    optionId: legacyOptionId,
    optionIds: optionIds,
    reuseScope: reuseScope,
    scope: schemaValue('scope', () => string(m['scope'])),
    code: schemaValue('code', () => string(m['code'])),
    label: schemaValue('label', () => string(m['label'])),
    description: schemaValue('description', () => m['description'] as String?),
    fieldType: schemaValue('fieldType', () => string(m['fieldType'])),
    required: schemaValue('required', () => boolean(m['required'])),
    requiresApproval: schemaValue(
      'requiresApproval',
      () => boolean(m['requiresApproval']),
    ),
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
    status: schemaValue('status', () => string(m['status'])),
  );
}

ProviderOnboardingSchema parseProviderSchema(Object? raw, int expectedId) {
  final m = schemaValue('root', () => object(raw));
  final s = schemaValue('serviceSetup', () => object(m['serviceSetup']));
  final id = schemaValue(
    'serviceTypeId',
    () => integer(m['serviceTypeId'], positive: true),
  );
  final configurationId = schemaValue(
    'configurationServiceTypeId',
    () => optionalInt(m['configurationServiceTypeId'], positive: true) ?? id,
  );
  if (id != expectedId) {
    throw const InvalidSchemaValue('serviceTypeId');
  }
  if (schemaValue(
        'serviceSetup.serviceTypeId',
        () => integer(s['serviceTypeId'], positive: true),
      ) !=
      configurationId) {
    throw const InvalidSchemaValue('serviceSetup.serviceTypeId');
  }
  final min = optionalInt(s['minimumOptionSelections']),
      max = optionalInt(s['maximumOptionSelections']);
  if (min != null && max != null && min > max) {
    throw const FormatException('Invalid option bounds');
  }
  final options = schemaValue('options', () => array(m['options'])).indexed
      .map(
        (entry) => schemaValue('options[${entry.$1}]', () {
          final raw = entry.$2;
          final o = object(raw),
              optionId = integer(o['optionId'], positive: true);
          final optionConfigurationId = schemaValue(
            'configurationServiceTypeId',
            () => optionalInt(o['configurationServiceTypeId'], positive: true),
          );
          // Linked option fields retain their source service ID. Only enforce
          // a parent configuration ID when the option explicitly supplies one.
          return ProviderSchemaOption(
            optionId: optionId,
            code: string(o['code']),
            name: string(o['name']),
            description: o['description'] as String?,
            displayOrder: optionalInt(o['displayOrder']) ?? 0,
            locationEnabled: o['locationEnabled'] == null
                ? true
                : boolean(o['locationEnabled']),
            defaultCapacity: optionalInt(o['defaultCapacity'], positive: true),
            bookingMode: o['bookingMode'] as String?,
            icon: parseProviderServiceMedia(o['icon']),
            deliveryModes: List.unmodifiable(
              (o['deliveryModes'] == null
                      ? <dynamic>[]
                      : array(o['deliveryModes']))
                  .map(string),
            ),
            fields: schemaValue('fields', () => array(o['fields'])).indexed
                .map(
                  (entry) => schemaValue(
                    'fields[${entry.$1}]',
                    () => field(entry.$2, optionConfigurationId, optionId),
                  ),
                )
                .toList(),
          );
        }),
      )
      .toList();
  if (options.map((o) => o.optionId).toSet().length != options.length) {
    throw const FormatException('Duplicate options');
  }
  return ProviderOnboardingSchema(
    serviceTypeId: id,
    serviceName: schemaValue('serviceName', () => string(m['serviceName'])),
    serviceSetup: ProviderServiceSetup(
      serviceTypeId: configurationId,
      name: schemaValue('serviceSetup.name', () => string(s['name'])),
      availabilityEnabled: schemaValue(
        'serviceSetup.availabilityEnabled',
        () => boolean(s['availabilityEnabled']),
      ),
      serviceAreasEnabled: schemaValue(
        'serviceSetup.serviceAreasEnabled',
        () => boolean(s['serviceAreasEnabled']),
      ),
      optionsRequired: schemaValue(
        'serviceSetup.optionsRequired',
        () => boolean(s['optionsRequired']),
      ),
      minimumOptionSelections: min,
      maximumOptionSelections: max,
      documents:
          schemaValue('serviceSetup.documents', () => array(s['documents']))
              .map(
                (v) => ProviderDocumentRequirement(
                  freeze(object(v)) as Map<String, Object?>,
                ),
              )
              .toList(),
      skills: schemaValue('serviceSetup.skills', () => array(s['skills']))
          .map(
            (v) => ProviderSkillRequirement(
              freeze(object(v)) as Map<String, Object?>,
            ),
          )
          .toList(),
      certificates: schemaValue(
        'serviceSetup.certificates',
        () => level(s['certificates']),
      ),
      education: schemaValue(
        'serviceSetup.education',
        () => level(s['education']),
      ),
    ),
    commonFields: schemaValue('commonFields', () => array(m['commonFields']))
        .indexed
        .map(
          (entry) => schemaValue(
            'commonFields[${entry.$1}]',
            () => field(entry.$2, configurationId, null),
          ),
        )
        .toList(),
    options: options..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
  );
}

ProviderOnboardingSchema applyPublicOptions(
  ProviderOnboardingSchema schema,
  Object? raw,
) {
  final configured = {
    for (final option in schema.options) option.optionId: option,
  };
  final seen = <int>{};
  final options = <ProviderSchemaOption>[];
  for (final value in array(raw)) {
    final item = object(value);
    final id = integer(item['optionId'] ?? item['id'], positive: true);
    if (!seen.add(id)) throw const FormatException('Duplicate public option');
    final source = configured[id];
    if (source == null) {
      throw const FormatException('Unconfigured public option');
    }
    options.add(
      ProviderSchemaOption(
        optionId: id,
        code: string(item['code']),
        name: string(item['name']),
        fields: source.fields,
        displayOrder: optionalInt(item['displayOrder']) ?? source.displayOrder,
        locationEnabled: item['locationEnabled'] == null
            ? source.locationEnabled
            : boolean(item['locationEnabled']),
        defaultCapacity:
            optionalInt(item['defaultCapacity'], positive: true) ??
            source.defaultCapacity,
        bookingMode: item['bookingMode'] as String? ?? source.bookingMode,
        description: item['description'] as String? ?? source.description,
        icon: parseProviderServiceMedia(item['icon']) ?? source.icon,
        deliveryModes: List.unmodifiable(
          item['deliveryModes'] == null
              ? source.deliveryModes
              : array(item['deliveryModes']).map(string),
        ),
      ),
    );
  }
  return ProviderOnboardingSchema(
    serviceTypeId: schema.serviceTypeId,
    serviceName: schema.serviceName,
    serviceSetup: schema.serviceSetup,
    commonFields: schema.commonFields,
    options: options..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
  );
}
