import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import '../../discovery/domain/customer_discovery.dart';

class BookingKey {
  const BookingKey(this.marketId, this.serviceId, this.optionId);
  final int marketId, serviceId, optionId;
  @override
  bool operator ==(Object other) =>
      other is BookingKey &&
      marketId == other.marketId &&
      serviceId == other.serviceId &&
      optionId == other.optionId;
  @override
  int get hashCode => Object.hash(marketId, serviceId, optionId);
}

class BookingProblem implements Exception {
  const BookingProblem(
    this.message, {
    this.status,
    this.errors = const {},
    this.eligibility = false,
  });
  final String message;
  final int? status;
  final Map<String, String> errors;
  final bool eligibility;
  @override
  String toString() => 'BookingProblem(status=$status)';
}

class BookingField {
  BookingField({
    required this.id,
    required this.code,
    required this.label,
    required this.type,
    required this.required,
    this.description,
    this.options = const [],
    this.condition,
    this.minFiles = 0,
    this.maxFiles,
    this.maxMb = 100,
    this.fileTypes = const [],
    this.order = 0,
    this.version = 1,
    this.iconUrl,
  });
  final int id, minFiles, maxMb, order, version;
  final int? maxFiles;
  final String code, label, type;
  final String? description;
  final String? iconUrl;
  final bool required;
  final List<Object?> options;
  final Map<String, dynamic>? condition;
  final List<String> fileTypes;
  static const types = {
    'TEXT',
    'TEXTAREA',
    'NUMBER',
    'BOOLEAN',
    'DATE',
    'TIME',
    'PHONE',
    'EMAIL',
    'SELECT',
    'MULTI_SELECT',
    'IMAGE_UPLOAD',
    'DOCUMENT_UPLOAD',
    'FILE_UPLOAD',
  };
  bool get upload => type.endsWith('_UPLOAD');
  factory BookingField.parse(
    Map<String, dynamic> data, {
    bool requirement = false,
    int? requirementId,
  }) {
    final type = text(data['fieldType']);
    if (!types.contains(type)) {
      throw const BookingProblem(
        'This form contains an unsupported field type. Please contact support.',
      );
    }
    if (data['required'] is! bool) {
      throw const FormatException('Invalid required flag');
    }
    final condition = data['condition'] == null
        ? null
        : object(data['condition']);
    if (condition != null &&
        !{'EQUALS', 'NOT_EQUALS'}.contains(condition['operator'] ?? 'EQUALS')) {
      throw const BookingProblem(
        'This form contains an unsupported condition. Please contact support.',
      );
    }
    final required = data['required'] as bool;
    final rawOptions = data[requirement ? 'choices' : 'options'];
    if (rawOptions != null && rawOptions is! List) {
      throw const FormatException('Invalid choices');
    }
    final allowed = data['allowedFileTypes'];
    if (allowed != null &&
        (allowed is! List || allowed.any((v) => v is! String))) {
      throw const FormatException('Invalid file types');
    }
    int? integer(String name) {
      final v = data[name];
      if (v != null && v is! int) {
        throw const FormatException('Invalid field limit');
      }
      return v as int?;
    }

    final field = BookingField(
      id: requirement ? positiveId(requirementId) : positiveId(data['fieldId']),
      code: text(data['code']),
      label: text(data['label']),
      type: type,
      required: required,
      description: optionalText(data['description']),
      iconUrl: data['icon'] is Map
          ? safeImageUrl((data['icon'] as Map)['url'])
          : null,
      options: rawOptions == null
          ? const []
          : List<Object?>.from(rawOptions as List),
      condition: condition,
      minFiles:
          integer('minimumFiles') ??
          (requirement
              ? 1
              : required
              ? 1
              : 0),
      maxFiles: integer('maximumFiles') ?? (requirement ? 1 : null),
      maxMb: integer('maximumFileSizeMb') ?? 100,
      fileTypes: allowed == null
          ? const []
          : List<String>.from(allowed as List),
      order: integer('displayOrder') ?? 0,
      version: integer('version') ?? 1,
    );
    if (field.maxMb < 1 ||
        field.minFiles < 0 ||
        (field.maxFiles != null && field.maxFiles! < field.minFiles)) {
      throw const FormatException('Invalid upload limits');
    }
    return field;
  }
  Object? choiceValue(Object? choice) =>
      choice is Map ? choice['value'] : choice;
  String choiceLabel(Object? choice) =>
      choice is Map ? '${choice['label'] ?? choice['value']}' : '$choice';
  bool applies(Map<String, Object?> answers) {
    if (condition == null) return true;
    final parent = condition!['fieldCode'];
    if (!answers.containsKey(parent) || answers[parent] == null) return false;
    final equal = const DeepCollectionEquality().equals(
      answers[parent],
      condition!['value'],
    );
    return (condition!['operator'] ?? 'EQUALS') == 'EQUALS' ? equal : !equal;
  }

  String? validate(Object? value, {bool reusable = false}) {
    final missing =
        value == null ||
        value is String && value.trim().isEmpty ||
        value is List && value.isEmpty;
    if (missing) return required ? 'Required' : null;
    if (upload) {
      final files = value is Map ? value['files'] : null;
      if (files is! List ||
          files.any(
            (f) =>
                f is! Map ||
                f['key'] is! String ||
                (f['key'] as String).isEmpty,
          )) {
        return 'Choose valid uploaded files';
      }
      if (files.isEmpty && !required) return null;
      if (files.length < minFiles ||
          maxFiles != null && files.length > maxFiles!) {
        return 'Choose $minFiles${maxFiles == null ? ' or more' : '–$maxFiles'} files';
      }
      if (files.map((f) => (f as Map)['key']).toSet().length != files.length) {
        return 'Remove duplicate files';
      }
      return null;
    }
    if (type == 'BOOLEAN') return value is bool ? null : 'Choose Yes or No';
    if (type == 'NUMBER') {
      return value is num && value.isFinite ? null : 'Enter a valid number';
    }
    if (type == 'SELECT') {
      return options.any(
            (c) => const DeepCollectionEquality().equals(choiceValue(c), value),
          )
          ? null
          : 'Choose an available option';
    }
    if (type == 'MULTI_SELECT') {
      if (value is! List ||
          value.isEmpty ||
          value.toSet().length != value.length ||
          value.any(
            (v) => !options.any(
              (c) => const DeepCollectionEquality().equals(choiceValue(c), v),
            ),
          )) {
        return 'Choose available options';
      }
      return null;
    }
    if (value is! String) return 'Enter valid text';
    if (reusable && value.runes.length > 4000) {
      return 'Use at most 4000 characters';
    }
    if (type == 'EMAIL' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    if (type == 'PHONE' && !RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    if (type == 'DATE') {
      final d = DateTime.tryParse(value);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          d == null ||
          d.toIso8601String().substring(0, 10) != value) {
        return 'Use YYYY-MM-DD';
      }
    }
    if (type == 'TIME' &&
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$').hasMatch(value)) {
      return 'Use HH:mm or HH:mm:ss';
    }
    return null;
  }
}

class BookingProviderFilter {
  BookingProviderFilter(this.id, this.label, this.type, this.options);
  final int id;
  final String label, type;
  final List<Map<String, String>> options;
  factory BookingProviderFilter.parse(Object? raw) {
    final row = object(raw);
    final type = text(row['fieldType']);
    final operator = switch (type) {
      'SELECT' || 'MULTI_SELECT' => 'IN',
      'NUMBER' => 'RANGE',
      'BOOLEAN' => 'EQUALS',
      _ => null,
    };
    if (operator == null || row['filterOperator'] != operator) {
      throw const FormatException('Unsupported provider filter');
    }
    final options = <Map<String, String>>[];
    if (operator == 'IN') {
      if (row['options'] is! List) {
        throw const FormatException('Invalid provider choices');
      }
      for (final choice in row['options'] as List) {
        final value = choice is String ? choice : object(choice)['value'];
        final label = choice is String
            ? choice
            : object(choice)['label'] ?? value;
        options.add({'value': text(value), 'label': text(label)});
      }
      if (options.map((e) => e['value']).toSet().length != options.length) {
        throw const FormatException('Duplicate provider choices');
      }
    }
    return BookingProviderFilter(
      positiveId(row['fieldId']),
      text(row['label']),
      type,
      options,
    );
  }
  Map<String, Object?>? serialize(Object? input) {
    if (input == null) return null;
    final output = <String, Object?>{'fieldId': id};
    if (type == 'BOOLEAN') {
      if (input is! bool) throw BookingProblem('$label: choose Yes or No.');
      output['value'] = input;
    } else if (type == 'NUMBER') {
      if (input is! Map) throw BookingProblem('$label: enter a valid range.');
      for (final bound in ['minimum', 'maximum']) {
        final raw = input[bound];
        if (raw == null || '$raw'.trim().isEmpty) continue;
        final value = num.tryParse('$raw');
        if (value == null || !value.isFinite) {
          throw BookingProblem('$label: enter a valid range.');
        }
        output[bound] = value;
      }
      if (output.length == 1) return null;
      if (output['minimum'] is num &&
          output['maximum'] is num &&
          (output['minimum'] as num) > (output['maximum'] as num)) {
        throw BookingProblem('$label: minimum must not exceed maximum.');
      }
    } else {
      if (input is! List ||
          input.length > 100 ||
          input.toSet().length != input.length ||
          input.any((v) => !options.any((o) => o['value'] == v))) {
        throw BookingProblem('$label: choose available options.');
      }
      if (input.isEmpty) return null;
      output['value'] = List<String>.from(input);
    }
    return output;
  }
}

class BookingContext {
  BookingContext(
    this.key,
    this.zone,
    this.selection,
    this.fields,
    this.skills,
    this.responsibilities, [
    this.providerFilters = const [],
    this.pricingFieldIds = const [],
  ]);
  final BookingKey key;
  final String zone;
  final Map<String, dynamic> selection;
  final List<BookingField> fields;
  final List<BookingProviderFilter> providerFilters;
  final List<int> pricingFieldIds;
  final List<Map<String, dynamic>> skills, responsibilities;
  Map<String, dynamic> get option => object(selection['option']);
  Map<String, dynamic> get access => object(selection['access']);
  String get name => text(option['name']);
  String get schedule => text(option['schedulingModel']);
  bool get route => schedule == 'ROUTE_BASED';
  bool get openRequest => option['providerSelectionMode'] == 'OPEN_REQUEST';
  int get providerCount => positiveId(option['requiredProviderCount']);
  List<String> get modes => List<String>.from(option['deliveryModes'] as List);
  List<String> get methods =>
      List<String>.from(option['allowedPaymentMethods'] as List);
  factory BookingContext.parse(Object? value, BookingKey key) {
    final root = object(value),
        selection = object(root['selection']),
        option = object(selection['option']);
    text(option['name']);
    object(selection['access']);
    MarketTime.location(text(root['timezone']));
    if (root['marketId'] != key.marketId ||
        option['serviceTypeId'] != key.serviceId ||
        option['optionId'] != key.optionId) {
      throw const FormatException('Booking context identity mismatch');
    }
    if (!{'TIME_BASED', 'ROUTE_BASED'}.contains(option['schedulingModel'])) {
      throw const BookingProblem('This scheduling model is not supported.');
    }
    if (option['deliveryModes'] is! List ||
        (option['deliveryModes'] as List).isEmpty ||
        (option['deliveryModes'] as List).any(
          (m) => !{
            'ONLINE',
            'PROVIDER_TO_CUSTOMER',
            'CUSTOMER_TO_PROVIDER',
          }.contains(m),
        )) {
      throw const FormatException('Unsupported delivery configuration');
    }
    positiveId(option['requiredProviderCount']);
    if (!{
      'DIRECT_REQUEST',
      'OPEN_REQUEST',
    }.contains(option['providerSelectionMode'])) {
      throw const FormatException('Invalid provider selection mode');
    }
    if (option['allowedPaymentMethods'] is! List ||
        (option['allowedPaymentMethods'] as List).any((m) => m is! String)) {
      throw const FormatException('Invalid payment methods');
    }
    final schema = object(root['bookingSchema']);
    if (schema['serviceTypeId'] != key.serviceId) {
      throw const FormatException('Invalid booking schema');
    }
    final common = schema['commonFields'], options = schema['options'];
    if (common is! List || options is! List) {
      throw const FormatException('Invalid booking fields');
    }
    final definitions = <Object?>[...common];
    for (final row in options) {
      final item = object(row);
      if (item['optionId'] == key.optionId) {
        if (item['fields'] is! List) {
          throw const FormatException('Invalid option fields');
        }
        definitions.addAll(item['fields'] as List);
      }
    }
    final byId = <int, BookingField>{};
    for (final raw in definitions) {
      final definition = object(raw);
      if (definition['scope'] != 'BOOKING_FIELD') {
        throw const FormatException('Invalid customer field scope');
      }
      final field = BookingField.parse(definition);
      if (byId.containsKey(field.id) &&
          jsonEncode(definition) !=
              jsonEncode(
                definitions.firstWhere((v) => object(v)['fieldId'] == field.id),
              )) {
        throw const FormatException('Conflicting field definitions');
      }
      byId[field.id] = field;
    }
    final fields = byId.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final codes = {for (final f in fields) f.code: f};
    if (codes.length != fields.length) {
      throw const FormatException('Duplicate field code');
    }
    for (final field in fields) {
      final seen = <String>{field.code};
      var condition = field.condition;
      while (condition != null) {
        final code = condition['fieldCode'];
        if (code is! String || !codes.containsKey(code) || !seen.add(code)) {
          throw const BookingProblem(
            'This form has invalid conditional fields.',
          );
        }
        condition = codes[code]!.condition;
      }
    }
    final setup = object(schema['serviceSetup']);
    final rawSkills = setup['skills'];
    // Skill IDs are exposed in serviceSetup; never derive them from answers.
    final skills = rawSkills is List
        ? rawSkills.map((e) => object(e)).toList()
        : <Map<String, dynamic>>[];
    for (final skill in skills) {
      positiveId(skill['skillId']);
      text(skill['name']);
    }
    final responsibilities = <Map<String, dynamic>>[];
    for (final raw in [option['responsibilities'], setup['responsibilities']]) {
      if (raw is List) responsibilities.addAll(raw.map((v) => object(v)));
    }
    final rawFilters = root['providerFilters'];
    if (rawFilters != null && rawFilters is! List) {
      throw const FormatException('Invalid provider filters');
    }
    final filters = (rawFilters as List? ?? const [])
        .map(BookingProviderFilter.parse)
        .toList();
    if (filters.map((f) => f.id).toSet().length != filters.length) {
      throw const FormatException('Duplicate provider filters');
    }
    final rawPricing = root['pricingFieldIds'];
    if (rawPricing != null && rawPricing is! List) {
      throw const FormatException('Invalid pricing fields');
    }
    final pricingIds = (rawPricing as List? ?? const [])
        .map(positiveId)
        .toList();
    if (pricingIds.length > 10 ||
        pricingIds.toSet().length != pricingIds.length ||
        pricingIds.any(
          (id) => !filters.any(
            (f) =>
                f.id == id &&
                {'SELECT', 'MULTI_SELECT'}.contains(f.type) &&
                f.options.isNotEmpty,
          ),
        )) {
      throw const FormatException('Unsupported pricing configuration');
    }
    return BookingContext(
      key,
      text(root['timezone']),
      selection,
      fields,
      skills,
      responsibilities,
      filters,
      pricingIds,
    );
  }
}

class CustomerRequirement {
  CustomerRequirement(
    this.field,
    this.status,
    this.value,
    this.expires,
    this.rejection,
    this.blocksBooking,
  );
  final BookingField field;
  final String status;
  final Object? value;
  final String? expires, rejection;
  final bool blocksBooking;
  factory CustomerRequirement.parse(Object? raw) {
    final row = object(raw),
        requirement = object(row['requirement']),
        definition = object(requirement['definition']);
    final submission = row['submission'] == null
        ? null
        : object(row['submission']);
    final field = BookingField.parse(
      definition,
      requirement: true,
      requirementId: positiveId(requirement['requirementId']),
    );
    final value = submission?['value'];
    if (field.upload && value != null) {
      final files = value is Map ? value['files'] : null;
      if (files is! List ||
          files.any(
            (f) =>
                f is! Map ||
                f['key'] is! String ||
                (f['key'] as String).isEmpty,
          )) {
        throw const FormatException('Invalid saved requirement files');
      }
    }
    return CustomerRequirement(
      field,
      submission == null ? 'MISSING' : text(submission['status']),
      submission?['value'],
      submission?['expiresOn'] as String?,
      submission?['rejectionReason'] as String?,
      definition['blocksBooking'] == true,
    );
  }
}

class ProviderCandidate {
  ProviderCandidate(this.data);
  final Map<String, dynamic> data;
  int get id => positiveId(data['providerId']);
  int? get locationId => data['providerLocationId'] as int?;
  String get key => '$id/${locationId ?? 'none'}';
  String get name => text(data['displayName']);
  String? get photo => safeImageUrl(data['profilePhoto']);
  String? get markerIcon {
    final marker = data['mapMarker'];
    final icon = marker is Map ? marker['icon'] : null;
    return icon is Map ? safeImageUrl(icon['url']) : null;
  }

  Map<String, dynamic>? get point =>
      data['mapPoint'] == null ? null : object(data['mapPoint']);
  factory ProviderCandidate.parse(Object? raw) {
    final candidate = ProviderCandidate(object(raw));
    candidate.id;
    candidate.name;
    candidate.photo;
    positiveId(candidate.data['assignmentId']);
    positiveId(candidate.data['remainingCapacity']);
    final rating = candidate.data['averageRating'],
        ratings = candidate.data['totalRatings'];
    if (rating != null && (rating is! num || !rating.isFinite) ||
        ratings != null && (ratings is! int || ratings < 0)) {
      throw const FormatException('Invalid provider rating');
    }
    final languages = candidate.data['languages'];
    if (languages is! List || languages.any((value) => value is! String)) {
      throw const FormatException('Invalid provider languages');
    }
    if (candidate.data['providerLocationId'] != null) {
      positiveId(candidate.data['providerLocationId']);
    }
    final point = candidate.point;
    if (point != null) GeoPoint.parse(point);
    return candidate;
  }
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  factory GeoPoint.parse(Map<String, dynamic> json) {
    final lat = json['latitude'], lng = json['longitude'];
    if (lat is! num || lng is! num) {
      throw const FormatException('Invalid coordinates');
    }
    final result = GeoPoint(lat.toDouble(), lng.toDouble());
    if (!result.valid) throw const FormatException('Invalid coordinates');
    return result;
  }
}

class MarketTime {
  static bool _initialized = false;
  static tz.Location location(String name) {
    if (!_initialized) {
      zones.initializeTimeZones();
      _initialized = true;
    }
    try {
      return tz.getLocation(name);
    } catch (_) {
      throw const BookingProblem('The market timezone is not supported.');
    }
  }

  static tz.TZDateTime parse(String value, String zone) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$')
        .hasMatch(value)) {
      throw const BookingProblem('Enter date and time as YYYY-MM-DDTHH:mm.');
    }
    final date = DateTime.tryParse(value);
    if (date == null ||
        date.toIso8601String().substring(0, 16) != value.substring(0, 16)) {
      throw const BookingProblem('Enter a valid date and time.');
    }
    final loc = location(zone);
    final result = tz.TZDateTime(
      loc,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
    );
    bool same(tz.TZDateTime v) =>
        v.year == date.year &&
        v.month == date.month &&
        v.day == date.day &&
        v.hour == date.hour &&
        v.minute == date.minute;
    if (!same(result)) {
      throw const BookingProblem(
        'This time does not exist in the market timezone. Choose another time.',
      );
    }
    for (final minutes in [-120, -90, -60, -30, 30, 60, 90, 120]) {
      if (same(
        tz.TZDateTime.from(result.add(Duration(minutes: minutes)), loc),
      )) {
        throw const BookingProblem(
          'This time is ambiguous in the market timezone. Choose another time.',
        );
      }
    }
    return result;
  }

  static String local(DateTime v) =>
      '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}T${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}:${v.second.toString().padLeft(2, '0')}';
  static String offset(tz.TZDateTime v) {
    final mins = v.timeZoneOffset.inMinutes;
    return '${local(v)}${mins < 0 ? '-' : '+'}${(mins.abs() ~/ 60).toString().padLeft(2, '0')}:${(mins.abs() % 60).toString().padLeft(2, '0')}';
  }

  static void interval(tz.TZDateTime start, tz.TZDateTime end, DateTime now) {
    if (!start.isAfter(now) ||
        !end.isAfter(start) ||
        end.difference(start) > const Duration(days: 31)) {
      throw const BookingProblem(
        'Choose a future start and a later end within 31 days.',
      );
    }
    for (
      var instant = start;
      instant.isBefore(end);
      instant = tz.TZDateTime.from(
        instant.add(const Duration(hours: 1)),
        start.location,
      )
    ) {
      if (instant.timeZoneOffset != start.timeZoneOffset) {
        throw const BookingProblem(
          'Choose an interval that does not cross a daylight-saving change.',
        );
      }
    }
    if (start.timeZoneOffset != end.timeZoneOffset) {
      throw const BookingProblem(
        'Choose an interval that does not cross a daylight-saving change.',
      );
    }
  }
}
