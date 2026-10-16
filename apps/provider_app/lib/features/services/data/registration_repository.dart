import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_providers.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/requirements/data/provider_schema_response.dart'
    as json;

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => RegistrationRepository(ref.watch(apiClientProvider)),
  dependencies: [apiClientProvider],
);

/// Provider API, section 9–20. Paths are relative to the configured /api/v1 base.
class RegistrationRepository {
  RegistrationRepository(this.client);
  final ApiClient client;
  String path(int assignment, String resource) {
    if (assignment <= 0) throw const FormatException('Invalid assignment');
    return '/providers/me/services/$assignment/$resource';
  }

  Future<Result<T>> safe<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on NetworkException catch (e) {
      return Failure(e.toAppFailure());
    } catch (_) {
      return const Failure(
        AppFailure(message: 'Unable to save service details. Please retry.'),
      );
    }
  }

  Future<Object?> read(int id, String resource) async =>
      (await client.get<Object?>(path(id, resource), requiresAuth: true)).data;
  Future<void> replace(int id, String resource, Object data) async {
    await client.put<Object?>(
      path(id, resource),
      data: data,
      requiresAuth: true,
    );
  }

  Future<Result<Map<String, dynamic>>> load(
    int id,
    ProviderServiceSetup setup,
  ) => safe(() async {
    final names = [
      'languages',
      'skills',
      'submissions',
      if (setup.availabilityEnabled) 'availability',
      if (setup.certificates.level != ProviderRequirementLevel.disabled)
        'certificates',
      if (setup.education.level != ProviderRequirementLevel.disabled)
        'education',
    ];
    final results = await Future.wait(names.map((name) => read(id, name)));
    final result = <String, dynamic>{};
    for (var i = 0; i < names.length; i++) {
      result[names[i]] = names[i] == 'availability'
          ? json.object(results[i])
          : json.array(results[i]);
    }
    return result;
  });
  Future<Result<Map<String, dynamic>>> loadOptionLocations(
    int assignmentId,
    List<ProviderSchemaOption> options,
  ) => safe(() async {
    final contexts = [
      for (final option in options)
        for (final mode in option.deliveryModes.where(physicalModes.contains))
          (option: option, mode: mode),
    ];
    final snapshots = await Future.wait([
      for (final context in contexts)
        read(
          assignmentId,
          'options/${context.option.optionId}/delivery-modes/${context.mode}/service-areas',
        ),
    ]);
    final restored = <String, dynamic>{};
    for (var index = 0; index < contexts.length; index++) {
      final context = contexts[index];
      final areas = json.array(snapshots[index]);
      if (areas.isNotEmpty) {
        restored.putIfAbsent(
          '${context.option.optionId}',
          () => {'deliveryMode': context.mode, 'areas': areas},
        );
      }
    }
    for (final option in options) {
      if (option.deliveryModes.length == 1 &&
          option.deliveryModes.single == 'ONLINE') {
        restored['${option.optionId}'] = {
          'deliveryMode': 'ONLINE',
          'areas': <Object>[],
        };
      }
    }
    return restored;
  });

  Future<Result<void>> languages(int id, List<String> values) => safe(() async {
    final languages = values.map((s) => s.toUpperCase()).toSet().toList();
    if (languages.any((s) => !['SINHALA', 'ENGLISH', 'TAMIL'].contains(s))) {
      throw const FormatException('Invalid language');
    }
    await replace(id, 'languages', {'languages': languages});
  });

  /// Step 2 may be retried after another section fails. Read fresh state rather
  /// than replaying the same language replacement or relying on a local flag.
  Future<Result<void>> saveLanguages(
    int id,
    List<String> values,
  ) => safe(() async {
    final requested = values.map((value) => value.toUpperCase()).toSet();
    const allowed = {'SINHALA', 'ENGLISH', 'TAMIL'};
    if (requested.isEmpty || !allowed.containsAll(requested)) {
      throw const FormatException('Invalid language');
    }
    Future<bool> matches() async {
      final saved = json.array(await read(id, 'languages'));
      if (saved.any((value) => value is! String || !allowed.contains(value))) {
        throw const FormatException('Invalid saved languages');
      }
      final existing = saved.cast<String>().toSet();
      return existing.length == requested.length &&
          existing.containsAll(requested);
    }

    if (await matches()) return;
    try {
      await replace(id, 'languages', {'languages': requested.toList()});
    } on NetworkException catch (failure) {
      final uncertain =
          failure.kind == NetworkExceptionKind.timeout ||
          failure.kind == NetworkExceptionKind.connection ||
          (failure.statusCode != null && failure.statusCode! >= 500);
      if (uncertain) {
        try {
          // A server may commit before returning an error. Only confirmed
          // read-back is success; an error alone never completes the step.
          if (await matches()) return;
        } catch (_) {
          // Preserve the original write failure when confirmation also fails.
        }
      }
      rethrow;
    }
  });
  Future<Result<void>> skills(int id, List<int> ids) => safe(() async {
    if (ids.any((id) => id <= 0)) throw const FormatException('Invalid skill');
    await replace(id, 'skills', {'skillIds': ids.toSet().toList()..sort()});
  });
  Future<Result<void>> availability(int id, Map<String, dynamic> value) =>
      safe(() async {
        final anyDay = value['availableAnyDay'] == true,
            anyTime = value['availableAnyTime'] == true;
        final slots = json.array(value['weeklySlots']);
        if ((anyDay && slots.isNotEmpty) || (!anyDay && slots.isEmpty)) {
          throw const FormatException('Invalid availability');
        }
        for (final raw in slots) {
          final slot = json.object(raw);
          if (!weekdays.contains(slot['dayOfWeek'])) {
            throw const FormatException('Invalid weekday');
          }
          if (!anyTime &&
              (!validTime(slot['startTime']) ||
                  !validTime(slot['endTime']) ||
                  (slot['startTime'] as String).compareTo(
                        slot['endTime'] as String,
                      ) >=
                      0)) {
            throw const FormatException('Invalid slot');
          }
        }
        await replace(id, 'availability', {
          'availableAnyDay': anyDay,
          'availableAnyTime': anyTime,
          'weeklySlots': [
            for (final raw in slots)
              {
                'dayOfWeek': json.object(raw)['dayOfWeek'],
                'startTime': anyTime ? null : json.object(raw)['startTime'],
                'endTime': anyTime ? null : json.object(raw)['endTime'],
              },
          ],
        });
      });
  static const weekdays = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  static bool validTime(Object? raw) =>
      raw is String &&
      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$').hasMatch(raw);
  Future<Result<List<Map<String, dynamic>>>> areas(
    int id,
    int optionId,
    String mode,
  ) => safe(() async {
    if (optionId <= 0 || !physicalModes.contains(mode)) {
      throw const FormatException('Invalid location context');
    }
    return json
        .array(
          await read(
            id,
            'options/$optionId/delivery-modes/$mode/service-areas',
          ),
        )
        .map((v) => Map<String, dynamic>.from(json.object(v)))
        .toList();
  });
  static const physicalModes = ['PROVIDER_TO_CUSTOMER', 'CUSTOMER_TO_PROVIDER'];
  Future<Result<void>> saveAreas(
    int id,
    int optionId,
    String mode,
    List<Map<String, dynamic>> areas,
  ) => safe(() async {
    if (optionId <= 0 || !physicalModes.contains(mode) || areas.isEmpty) {
      throw const FormatException('Invalid locations');
    }
    final values = <Map<String, dynamic>>[];
    for (final area in areas) {
      final latitude = area['latitude'],
          longitude = area['longitude'],
          radius = area['radiusKm'];
      if (latitude is! num ||
          !latitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude is! num ||
          !longitude.isFinite ||
          longitude < -180 ||
          longitude > 180 ||
          (mode == 'PROVIDER_TO_CUSTOMER' &&
              (radius is! num || !radius.isFinite || radius <= 0))) {
        throw const FormatException('Invalid coordinates');
      }
      values.add({
        for (final key in [
          'locationName',
          'country',
          'province',
          'district',
          'city',
          'latitude',
          'longitude',
          'capacity',
        ])
          key: area[key],
        'radiusKm': mode == 'CUSTOMER_TO_PROVIDER' ? null : radius,
      });
    }
    await replace(
      id,
      'options/$optionId/delivery-modes/$mode/service-areas',
      values,
    );
  });
  Future<Result<void>> submissions(int id, List<Map<String, dynamic>> fields) =>
      safe(() async {
        final ids = <int>{};
        for (final f in fields) {
          final fieldId = f['fieldId'];
          if (fieldId is! int || fieldId <= 0 || !ids.add(fieldId)) {
            throw const FormatException('Invalid field');
          }
        }
        await replace(id, 'submissions', {
          'submissions': fields
              .map((f) => {'fieldId': f['fieldId'], 'value': f['value']})
              .toList(),
        });
      });
  Future<Result<void>> addQualification(
    int id,
    String resource,
    Map<String, dynamic> input,
  ) => safe(() async {
    if (!['certificates', 'education'].contains(resource)) {
      throw const FormatException('Invalid qualification');
    }
    await client.post<Object?>(
      path(id, resource),
      data: input,
      requiresAuth: true,
    );
  });

  Future<Result<List<Map<String, dynamic>>>> unavailableDates(int id) => safe(
    () async => json
        .array(await read(id, 'unavailable-dates'))
        .map((v) => Map<String, dynamic>.from(json.object(v)))
        .toList(),
  );
  Future<Result<void>> addUnavailableDate(
    int id,
    String date,
    String? reason,
  ) => safe(() async {
    if (DateTime.tryParse(date)?.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid date');
    }
    await client.post<Object?>(
      path(id, 'unavailable-dates'),
      data: {'date': date, 'reason': reason},
      requiresAuth: true,
    );
  });
  Future<Result<void>> deleteUnavailableDate(int id, int dateId) => safe(
    () async {
      if (dateId <= 0) throw const FormatException('Invalid unavailable date');
      await client.delete<Object?>(
        path(id, 'unavailable-dates/$dateId'),
        requiresAuth: true,
      );
    },
  );
}
