import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/services/data/registration_repository.dart';
import 'package:provider_app/features/services/application/registration_payload.dart';
import 'package:provider_app/features/onboarding/requirements/data/provider_schema_response.dart';

import 'support/fake_session_storage.dart';
import 'provider_options_test.dart' show optionsSchema;
import 'support/fake_schema_repository.dart' show fieldJson;
import 'support/fake_registration_repository.dart';

class RegistrationAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final responses = <String, Object?>{};
  String? failResource;
  ResponseBody Function(RequestOptions)? handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (handler != null) return handler!(options);
    return ResponseBody.fromString(
      jsonEncode(responses[options.path] ?? []),
      options.path.endsWith(failResource ?? 'never') ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late RegistrationAdapter adapter;
  late RegistrationRepository repository;
  late ApiClient client;
  setUp(() {
    adapter = RegistrationAdapter();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: adapter,
      tokenProvider: SessionAccessTokenProvider(
        FakeSessionStorage()..session = testSession(),
        now: () => testNow,
      ),
    );
    repository = RegistrationRepository(client);
  });
  tearDown(() => client.close(force: true));
  test('saved languages replace empty defaults and clean stale drafts', () {
    final server = {
      'languages': ['ENGLISH', 'SINHALA'],
    };
    expect(mergeRegistrationSnapshot({'languages': []}, server)['languages'], [
      'ENGLISH',
      'SINHALA',
    ]);
    expect(
      mergeRegistrationSnapshot({
        'languages': ['TAMIL'],
        '_languagesEdited': false,
      }, server)['languages'],
      ['ENGLISH', 'SINHALA'],
    );
    expect(
      mergeRegistrationSnapshot(
        {
          'languages': ['TAMIL'],
          '_languagesEdited': false,
        },
        {'languages': []},
      )['languages'],
      isEmpty,
    );
  });
  test('pending language changes survive restoration including intentional clearing', () {
    final server = {
      'languages': ['ENGLISH'],
    };
    expect(
      mergeRegistrationSnapshot({
        'languages': ['tamil'],
        '_languagesEdited': true,
      }, server)['languages'],
      ['TAMIL'],
    );
    expect(
      mergeRegistrationSnapshot({
        'languages': [],
        '_languagesEdited': true,
      }, server)['languages'],
      isEmpty,
    );
    expect(
      mergeRegistrationSnapshot({
        'languages': ['Sinhala'],
        '_step': 2,
      }, server)['languages'],
      ['SINHALA'],
    );
    expect(
      mergeRegistrationSnapshot(
        {
          'languages': ['Sinhala'],
        },
        {'languages': []},
      )['languages'],
      ['SINHALA'],
    );
  });
  test('Step 2 skips an unchanged saved language set using fresh authenticated state', () async {
    adapter.responses['/providers/me/services/14/languages'] = [
      'ENGLISH',
      'SINHALA',
    ];
    expect(
      await repository.saveLanguages(14, ['Sinhala', 'English', 'English']),
      isA<Success<void>>(),
    );
    expect(adapter.requests.map((request) => request.method), ['GET']);
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer synthetic-access',
    );
  });
  for (final commits in [false, true]) {
    test(
      'failed language PUT ${commits ? 'recovers only after confirmed commit' : 'keeps an unsaved change failed'}',
      () async {
        var saved = ['ENGLISH'];
        adapter.handler = (request) {
          if (request.method == 'PUT' && commits) saved = ['TAMIL'];
          return ResponseBody.fromString(
            jsonEncode(saved),
            request.method == 'PUT' ? 500 : 200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        };
        final result = await repository.saveLanguages(14, ['TAMIL']);
        expect(result, commits ? isA<Success<void>>() : isA<Failure<void>>());
        expect(adapter.requests.map((request) => request.method), [
          'GET',
          'PUT',
          'GET',
        ]);
        expect(adapter.requests[1].data, {
          'languages': ['TAMIL'],
        });
      },
    );
  }
  test(
    'failed initial language read never triggers a blind replacement',
    () async {
      adapter.failResource = 'languages';
      expect(
        await repository.saveLanguages(14, ['ENGLISH']),
        isA<Failure<void>>(),
      );
      expect(adapter.requests.map((request) => request.method), ['GET']);
    },
  );
  test(
    'retrying a later failed section never repeats unchanged languages',
    () async {
      adapter.responses['/providers/me/services/14/languages'] = ['ENGLISH'];
      adapter.failResource = 'availability';
      final schema = parseProviderSchema(optionsSchema(), 3);
      for (var attempt = 0; attempt < 2; attempt++) {
        expect(
          await saveRegistrationRequirements(repository, 14, schema, {
            12,
          }, readyRegistrationDraft()),
          isA<Failure<void>>(),
        );
      }
      expect(
        adapter.requests.where(
          (request) =>
              request.path.endsWith('/languages') && request.method == 'PUT',
        ),
        isEmpty,
      );
      expect(
        adapter.requests.where(
          (request) =>
              request.path.endsWith('/availability') && request.method == 'PUT',
        ),
        hasLength(2),
      );
    },
  );
  test(
    'public option delivery modes and descriptions survive schema loading',
    () {
      final schema = parseProviderSchema(optionsSchema(), 3);
      final enriched = applyPublicOptions(schema, [
        for (final option in schema.options)
          {
            'optionId': option.optionId,
            'code': option.code,
            'name': option.name,
            'description': 'Support for older adults',
            'deliveryModes': ['PROVIDER_TO_CUSTOMER'],
          },
      ]);
      expect(enriched.options.first.description, 'Support for older adults');
      expect(enriched.options.first.deliveryModes, ['PROVIDER_TO_CUSTOMER']);
      final draft = readyRegistrationDraft();
      (draft['options'] as Map)['12'] = {
        'deliveryMode': 'ONLINE',
        'areas': <Object>[],
      };
      expect(
        validateRegistrationDraft(enriched, {12}, draft),
        contains('supported delivery mode'),
      );
    },
  );
  test(
    'skill IDs distinguish duplicate labels and preserve server identities',
    () async {
      final data = optionsSchema();
      data['serviceSetup']['skills'] = [
        {'skillId': 10, 'name': 'Care', 'required': false},
        {'skillId': 11, 'name': 'Care', 'required': false},
      ];
      final schema = parseProviderSchema(data, 3);
      final draft = readyRegistrationDraft()
        ..['skillIds'] = [11]
        ..['skills'] = ['Care'];
      expect(registrationSkillIds(schema, draft), {11});
      expect(
        await saveRegistrationRequirements(repository, 14, schema, {12}, draft),
        isA<Success<void>>(),
      );
      expect(
        adapter.requests
            .singleWhere((request) => request.path.endsWith('/skills'))
            .data,
        {
          'skillIds': [11],
        },
      );
      final snapshot = mergeRegistrationSnapshot({}, {
        'skills': [
          {'skillId': 11, 'skillName': 'Care'},
        ],
      });
      expect(registrationSkillIds(schema, snapshot), {11});
    },
  );
  test('saved option locations load using the assignment and supported mode', () async {
    final schema = applyPublicOptions(parseProviderSchema(optionsSchema(), 3), [
      for (final id in [12, 13, 14])
        {
          'optionId': id,
          'code': 'OPTION_$id',
          'name': 'Option $id',
          'deliveryModes': ['CUSTOMER_TO_PROVIDER'],
        },
    ]);
    adapter
        .responses['/providers/me/services/14/options/12/delivery-modes/CUSTOMER_TO_PROVIDER/service-areas'] = [
      {
        'locationName': 'Saved location',
        'latitude': 6.9,
        'longitude': 79.8,
        'radiusKm': null,
      },
    ];
    final result = await repository.loadOptionLocations(14, [
      schema.options.first,
    ]);
    expect(result, isA<Success<Map<String, dynamic>>>());
    final restored = (result as Success<Map<String, dynamic>>).value;
    expect(restored['12']['deliveryMode'], 'CUSTOMER_TO_PROVIDER');
    expect(restored['12']['areas'].single['locationName'], 'Saved location');
    expect(adapter.requests.single.method, 'GET');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer synthetic-access',
    );
  });
  test('languages and skills use assignment IDs, authenticated replacements and documented values', () async {
    expect(
      await repository.languages(14, ['Sinhala', 'English']),
      isA<Success<void>>(),
    );
    expect(await repository.skills(14, [11, 10, 10]), isA<Success<void>>());
    expect(adapter.requests.map((r) => r.path), [
      '/providers/me/services/14/languages',
      '/providers/me/services/14/skills',
    ]);
    expect(adapter.requests[0].data, {
      'languages': ['SINHALA', 'ENGLISH'],
    });
    expect(adapter.requests[1].data, {
      'skillIds': [10, 11],
    });
    expect(
      adapter.requests.every(
        (r) =>
            r.method == 'PUT' &&
            r.headers['Authorization'] == 'Bearer synthetic-access',
      ),
      isTrue,
    );
    expect(await repository.languages(14, ['Hindi']), isA<Failure<void>>());
    expect(adapter.requests.length, 2);
  });
  test(
    'availability validates and serializes weekly slots without response IDs',
    () async {
      final input = {
        'availableAnyDay': false,
        'availableAnyTime': false,
        'weeklySlots': [
          {
            'availabilityId': 30,
            'dayOfWeek': 'MONDAY',
            'startTime': '08:00:00',
            'endTime': '17:00:00',
          },
        ],
      };
      expect(await repository.availability(14, input), isA<Success<void>>());
      expect(adapter.requests.single.data, {
        'availableAnyDay': false,
        'availableAnyTime': false,
        'weeklySlots': [
          {
            'dayOfWeek': 'MONDAY',
            'startTime': '08:00:00',
            'endTime': '17:00:00',
          },
        ],
      });
      expect(
        await repository.availability(14, {
          'availableAnyDay': false,
          'availableAnyTime': true,
          'weeklySlots': [],
        }),
        isA<Failure<void>>(),
      );
      expect(
        await repository.availability(14, {
          'availableAnyDay': true,
          'availableAnyTime': true,
          'weeklySlots': [],
        }),
        isA<Success<void>>(),
      );
    },
  );
  test('locations use direct arrays, option and mode paths, validated coordinates and null radius for premises', () async {
    final area = {
      'locationName': 'Clinic',
      'country': 'Sri Lanka',
      'province': 'Western',
      'district': 'Colombo',
      'city': 'Colombo',
      'latitude': 6.9271,
      'longitude': 79.8612,
      'radiusKm': 20,
      'capacity': 5,
      'serviceAreaId': 50,
    };
    expect(
      await repository.saveAreas(14, 12, 'CUSTOMER_TO_PROVIDER', [area]),
      isA<Success<void>>(),
    );
    expect(
      adapter.requests.single.path,
      '/providers/me/services/14/options/12/delivery-modes/CUSTOMER_TO_PROVIDER/service-areas',
    );
    final payload = adapter.requests.single.data as List;
    expect(payload.single['radiusKm'], isNull);
    expect(payload.single.containsKey('serviceAreaId'), isFalse);
    expect(
      await repository.saveAreas(14, 12, 'ONLINE', [area]),
      isA<Failure<void>>(),
    );
    expect(
      await repository.saveAreas(14, 12, 'PROVIDER_TO_CUSTOMER', [
        {...area, 'latitude': 100},
      ]),
      isA<Failure<void>>(),
    );
    expect(adapter.requests.length, 1);
  });
  test(
    'submissions retain numeric, boolean, array and uploaded key JSON types',
    () async {
      final fields = [
        {'fieldId': 20, 'value': 'Experience'},
        {'fieldId': 21, 'value': 3},
        {'fieldId': 22, 'value': true},
        {
          'fieldId': 23,
          'value': ['OPTION_A'],
        },
        {
          'fieldId': 24,
          'value': {
            'files': [
              {'key': 'providers/25/documents/file.pdf'},
            ],
          },
        },
      ];
      expect(await repository.submissions(14, fields), isA<Success<void>>());
      expect(adapter.requests.single.data, {'submissions': fields});
      expect(
        adapter.requests.single.path,
        '/providers/me/services/14/submissions',
      );
    },
  );
  test(
    'certificates and education use POST; failures remain retryable',
    () async {
      expect(
        await repository.addQualification(14, 'certificates', {
          'name': 'Nursing',
          'documentKey': 'key.pdf',
        }),
        isA<Success<void>>(),
      );
      expect(adapter.requests.single.method, 'POST');
      adapter.failResource = 'skills';
      expect(await repository.skills(14, [10]), isA<Failure<void>>());
    },
  );
  test(
    'snapshot uses only applicable resources and preserves server values',
    () async {
      final schema = parseProviderSchema(optionsSchema(), 3);
      adapter.responses['/providers/me/services/14/availability'] = {
        'availableAnyDay': true,
        'availableAnyTime': true,
        'weeklySlots': [],
      };
      adapter.responses['/providers/me/services/14/languages'] = ['TAMIL'];
      final result = await repository.load(14, schema.serviceSetup);
      expect(result, isA<Success<Map<String, dynamic>>>());
      final draft = mergeRegistrationSnapshot(
        {},
        (result as Success<Map<String, dynamic>>).value,
      );
      expect(draft['languages'], ['TAMIL']);
      expect(adapter.requests.any((r) => r.path.endsWith('/submit')), isFalse);
    },
  );
  test('required fields and conditions validate typed answers', () {
    final j = optionsSchema();
    j['commonFields'] = [
      fieldJson()
        ..['fieldType'] = 'BOOLEAN'
        ..['code'] = 'needs_care',
      fieldJson()
        ..['fieldId'] = 50
        ..['fieldType'] = 'NUMBER'
        ..['condition'] = {
          'fieldCode': 'needs_care',
          'operator': 'EQUALS',
          'value': true,
        },
    ];
    final fields = parseProviderSchema(j, 3).commonFields;
    expect(registrationFieldVisible(fields[1], {'7': false}, fields), isFalse);
    expect(validateRegistrationAnswer(fields[1], '3'), isNotNull);
    expect(validateRegistrationAnswer(fields[1], 3), isNull);
  });
  test('upload answers always serialize with the required files array', () {
    final json = fieldJson()
      ..['fieldType'] = 'FILE_UPLOAD'
      ..['minimumFiles'] = 1
      ..['maximumFiles'] = 2;
    final field = parseProviderSchema(
      optionsSchema()..['commonFields'] = [json],
      3,
    ).commonFields.single;
    expect(
      registrationSubmissionValue(field, {
        'key': 'providers/25/documents/file.pdf',
      }),
      {
        'files': [
          {'key': 'providers/25/documents/file.pdf'},
        ],
      },
    );
    expect(
      validateRegistrationAnswer(field, {
        'files': [
          {'key': 'providers/25/documents/file.pdf'},
        ],
      }),
      isNull,
    );
  });
  test(
    'unchanged inherited answers are not converted into new submissions',
    () async {
      final schema = parseProviderSchema(optionsSchema(fields: true), 3);
      final repository = FakeRegistrationRepository();
      final draft = readyRegistrationDraft();
      (draft['options'] as Map)['12'] = {
        'deliveryMode': 'ONLINE',
        'areas': <Object>[],
        'saved': true,
        'fields': {'7': 'Inherited answer'},
      };
      draft['server'] = {
        'submissions': [
          {
            'fieldId': 7,
            'value': 'Inherited answer',
            'reused': true,
            'reuseScope': 'PROVIDER',
            'sourceAssignmentId': 4,
            'verificationStatus': 'APPROVED',
          },
        ],
      };
      expect(
        await saveRegistrationRequirements(repository, 14, schema, {12}, draft),
        isA<Success<void>>(),
      );
      expect(repository.submittedValues, isEmpty);
    },
  );
}
