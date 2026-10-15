import 'dart:convert';

import 'package:bthere_common/bthere_common.dart';

import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../data/registration_repository.dart';

List<ProviderRequirementField> activeRegistrationFields(
  ProviderOnboardingSchema schema,
  Set<int> selected,
) {
  final unique = <int, ProviderRequirementField>{};
  for (final field in [
    ...schema.commonFields,
    ...schema.options
        .where((o) => selected.contains(o.optionId))
        .expand((o) => o.fields),
  ]) {
    if (field.status == 'ACTIVE' && field.scope == 'PROVIDER_REQUIREMENT') {
      unique.putIfAbsent(field.fieldId, () => field);
    }
  }
  return unique.values.toList()
    ..sort((a, b) => (a.displayOrder ?? 0).compareTo(b.displayOrder ?? 0));
}

List<Map<String, dynamic>>? registrationFiles(Object? value) {
  final raw = value is Map && value['files'] is List
      ? value['files'] as List
      : value is List
      ? value
      : value is Map && value['key'] is String
      ? [value]
      : null;
  if (raw == null) return null;
  final files = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map || item['key'] is! String) return null;
    final key = (item['key'] as String).trim();
    if (key.isEmpty) return null;
    files.add({'key': key});
  }
  return files;
}

Object? registrationSubmissionValue(
  ProviderRequirementField field,
  Object? value,
) =>
    ['IMAGE_UPLOAD', 'DOCUMENT_UPLOAD', 'FILE_UPLOAD'].contains(field.fieldType)
    ? {'files': registrationFiles(value) ?? const <Map<String, dynamic>>[]}
    : value;

Map<String, dynamic> registrationAnswers(Map<String, dynamic> draft) => {
  ...Map<String, dynamic>.from(draft['fields'] as Map? ?? {}),
  for (final option in (draft['options'] as Map? ?? {}).values.whereType<Map>())
    ...Map<String, dynamic>.from(option['fields'] as Map? ?? {}),
};

/// A null result denotes an unsupported condition, never an assumed answer.
bool? registrationFieldVisible(
  ProviderRequirementField field,
  Map<String, dynamic> answers,
  List<ProviderRequirementField> fields,
) {
  final condition = field.condition;
  if (condition == null) return true;
  if (condition is! Map) return null;
  final reference =
      condition['fieldId'] ?? condition['fieldCode'] ?? condition['field'];
  final referenced = fields
      .where((f) => f.fieldId == reference || f.code == reference)
      .firstOrNull;
  if (referenced == null) return null;
  final value = answers['${referenced.fieldId}'];
  return switch (condition['operator']) {
    'EQUALS' => value == condition['value'],
    'NOT_EQUALS' => value != condition['value'],
    _ => null,
  };
}

String? validateRegistrationAnswer(
  ProviderRequirementField field,
  Object? value,
) {
  if (value == null || value == '' || (value is List && value.isEmpty)) {
    return field.required ? '${field.label} is required.' : null;
  }
  if ([
    'IMAGE_UPLOAD',
    'DOCUMENT_UPLOAD',
    'FILE_UPLOAD',
  ].contains(field.fieldType)) {
    final files = registrationFiles(value);
    if (files == null || files.isEmpty) {
      return 'Upload ${field.label}.';
    }
    if (field.minimumFiles != null && files.length < field.minimumFiles!) {
      return 'Upload at least ${field.minimumFiles} files for ${field.label}.';
    }
    if (field.maximumFiles != null && files.length > field.maximumFiles!) {
      return 'Upload at most ${field.maximumFiles} files for ${field.label}.';
    }
    return null;
  }
  return switch (field.fieldType) {
    'NUMBER' when value is! num || !value.isFinite =>
      '${field.label} must be a number.',
    'BOOLEAN' when value is! bool => '${field.label} must be Yes or No.',
    'EMAIL'
        when value is! String ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value) =>
      'Enter a valid email address.',
    'TIME' when !RegistrationRepository.validTime(value) =>
      'Enter a valid time.',
    'DATE'
        when value is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
            DateTime.tryParse(value)?.toIso8601String().substring(0, 10) !=
                value =>
      'Enter a valid date.',
    _ => null,
  };
}

/// IDs are authoritative; names support drafts created before ID-based selection.
Set<int> registrationSkillIds(
  ProviderOnboardingSchema schema,
  Map<String, dynamic> draft,
) {
  if (draft['skillIds'] is List) {
    return (draft['skillIds'] as List).whereType<int>().toSet();
  }
  final names = draft['skills'] as List? ?? [];
  return {
    for (final skill in schema.serviceSetup.skills)
      if (names.contains(skill.metadata['name']) &&
          skill.metadata['skillId'] is int)
        skill.metadata['skillId'] as int,
  };
}

String? validateRegistrationDraft(
  ProviderOnboardingSchema schema,
  Set<int> selected,
  Map<String, dynamic> draft,
) {
  final languages = draft['languages'] as List? ?? [];
  if (languages.isEmpty) return 'Select at least one language.';
  final chosen = registrationSkillIds(schema, draft);
  final configuredIds = schema.serviceSetup.skills
      .map((skill) => skill.metadata['skillId'])
      .toSet();
  if (!configuredIds.containsAll(chosen)) {
    return 'Some selected skills are no longer available. Reload this service.';
  }
  for (final skill in schema.serviceSetup.skills) {
    if (skill.metadata['required'] == true &&
        !chosen.contains(skill.metadata['skillId'])) {
      return 'Select the required skill: ${skill.metadata['name']}.';
    }
    if ((draft['skills'] as List? ?? []).contains(skill.metadata['name']) &&
        skill.metadata['skillId'] is! int) {
      return 'Skill configuration is unavailable. Please reload the service.';
    }
  }
  if (schema.serviceSetup.availabilityEnabled) {
    final availability = draft['availability'];
    if (availability is! Map ||
        (availability['availableAnyDay'] != true &&
            (availability['weeklySlots'] as List? ?? []).isEmpty)) {
      return 'Configure weekly availability for your service.';
    }
  }
  final answers = registrationAnswers(draft),
      fields = activeRegistrationFields(schema, selected);
  for (final field in fields) {
    final visible = registrationFieldVisible(field, answers, fields);
    if (visible == null) {
      return 'The condition for ${field.label} needs a supported service configuration.';
    }
    if (!visible) continue;
    final validation = validateRegistrationAnswer(
      field,
      answers['${field.fieldId}'],
    );
    if (validation != null) return validation;
  }
  if (schema.serviceSetup.serviceAreasEnabled) {
    final options = draft['options'] as Map? ?? {};
    for (final id in selected) {
      final option = options['$id'];
      if (option is! Map || option['deliveryMode'] == null) {
        return 'Choose the delivery mode for each selected service.';
      }
      final configured = schema.options
          .where((option) => option.optionId == id)
          .firstOrNull;
      if (configured != null &&
          configured.deliveryModes.isNotEmpty &&
          !configured.deliveryModes.contains(option['deliveryMode'])) {
        return 'Choose a supported delivery mode for ${configured.name}.';
      }
      if (option['deliveryMode'] != 'ONLINE' &&
          (option['areas'] as List? ?? []).isEmpty) {
        return 'Add a location for each physical service.';
      }
    }
  }
  return null;
}

/// Every operation is an idempotent replacement. No application submission API exists.
Future<Result<void>> saveRegistrationRequirements(
  RegistrationRepository repository,
  int assignmentId,
  ProviderOnboardingSchema schema,
  Set<int> selected,
  Map<String, dynamic> draft,
) async {
  final validation = validateRegistrationDraft(schema, selected, draft);
  if (validation != null) return Failure(AppFailure(message: validation));
  var result = await repository.languages(
    assignmentId,
    List<String>.from(draft['languages'] as List),
  );
  if (result is Failure<void>) return result;
  if (schema.serviceSetup.skills.isNotEmpty) {
    result = await repository.skills(assignmentId, [
      for (final s in schema.serviceSetup.skills)
        if (registrationSkillIds(schema, draft).contains(s.metadata['skillId']))
          s.metadata['skillId'] as int,
    ]);
    if (result is Failure<void>) return result;
  }
  if (schema.serviceSetup.availabilityEnabled) {
    result = await repository.availability(
      assignmentId,
      Map<String, dynamic>.from(draft['availability'] as Map),
    );
    if (result is Failure<void>) return result;
  }
  if (schema.serviceSetup.serviceAreasEnabled) {
    final options = draft['options'] as Map;
    for (final id in selected) {
      final option = options['$id'] as Map;
      final mode = option['deliveryMode'] as String;
      if (mode == 'ONLINE') continue;
      result = await repository.saveAreas(
        assignmentId,
        id,
        mode,
        (option['areas'] as List)
            .map((a) => Map<String, dynamic>.from(a as Map))
            .toList(),
      );
      if (result is Failure<void>) return result;
    }
  }
  final fields = activeRegistrationFields(schema, selected),
      answers = registrationAnswers(draft);
  if (fields.isNotEmpty) {
    final previous = <int, Map>{
      for (final submission
          in ((draft['server'] as Map?)?['submissions'] as List? ?? [])
              .whereType<Map>())
        if (submission['fieldId'] is int)
          submission['fieldId'] as int: submission,
    };
    result = await repository.submissions(assignmentId, [
      for (final f in fields)
        if (registrationFieldVisible(f, answers, fields) == true &&
            answers['${f.fieldId}'] != null &&
            !(previous[f.fieldId]?['reused'] == true &&
                jsonEncode(previous[f.fieldId]?['value']) ==
                    jsonEncode(
                      registrationSubmissionValue(f, answers['${f.fieldId}']),
                    )))
          {
            'fieldId': f.fieldId,
            'value': registrationSubmissionValue(f, answers['${f.fieldId}']),
          },
    ]);
  }
  return result;
}

Map<String, dynamic> mergeRegistrationSnapshot(
  Map<String, dynamic> draft,
  Map<String, dynamic> server,
) {
  final submissions = (server['submissions'] as List? ?? []).whereType<Map>();
  return {
    'languages': (server['languages'] as List? ?? [])
        .map((v) => v.toString())
        .toList(),
    if (!draft.containsKey('skills') && !draft.containsKey('skillIds'))
      'skillIds': (server['skills'] as List? ?? [])
          .whereType<Map>()
          .map((skill) => skill['skillId'])
          .whereType<int>()
          .toList(),
    'skills': (server['skills'] as List? ?? [])
        .whereType<Map>()
        .map((v) => v['skillName'])
        .whereType<String>()
        .toList(),
    if (server['availability'] != null) 'availability': server['availability'],
    ...draft,
    'fields': {
      for (final f in submissions) '${f['fieldId']}': f['value'],
      ...Map<String, dynamic>.from(draft['fields'] as Map? ?? {}),
    },
    'server': server,
  };
}
