import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/core/auth/session_access_token_provider.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_remote_data_source.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_repository_impl.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/domain/provider_completion.dart';

import 'support/fake_completion_repository.dart';
import 'support/fake_session_storage.dart';

final class CompletionAdapter implements HttpClientAdapter {
  Object? body = completionJson();
  int status = 200;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('completion and every service field parse immutably', () {
    final completion = parseProviderCompletion(
      completionJson(step: 'COMPLETE_SERVICE_REQUIREMENTS'),
    );
    expect(completion.profileCompleted, isTrue);
    expect(completion.marketSelected, isTrue);
    expect(completion.serviceSelected, isTrue);
    expect(completion.allActiveServicesApproved, isFalse);
    expect(completion.completionPercentage, 75);
    expect(
      completion.nextStep,
      ProviderOnboardingStep.completeServiceRequirements,
    );
    final service = completion.services.single;
    expect(service.assignmentId, 14);
    expect(service.serviceTypeId, 3);
    expect(service.serviceName, 'Home Nurse');
    expect(service.documentsCompleted, isFalse);
    expect(service.skillsCompleted, isTrue);
    expect(service.certificatesCompleted, isFalse);
    expect(service.educationCompleted, isTrue);
    expect(service.availabilityCompleted, isTrue);
    expect(service.serviceAreasCompleted, isTrue);
    expect(service.optionsCompleted, isFalse);
    expect(service.customRequirementsCompleted, isTrue);
    expect(service.verificationStatus, 'PENDING');
    expect(service.effectiveStatus, 'ACTIVE');
    expect(() => completion.services.clear(), throwsUnsupportedError);
    expect(
      parseProviderCompletion(completionJson()..['completionPercentage'] = 75.5)
          .completionPercentage,
      75.5,
    );
    expect(
      parseProviderCompletion(completionJson()..['services'] = []).services,
      isEmpty,
    );
  });
  test('unknown nextStep is unsupported, never completed', () {
    expect(
      () => parseProviderCompletion(completionJson(step: 'FUTURE_STEP')),
      throwsA(isA<UnsupportedOnboardingStep>()),
    );
  });
  for (final field in [
    'profileCompleted',
    'marketSelected',
    'serviceSelected',
    'allActiveServicesApproved',
    'completionPercentage',
    'nextStep',
    'services',
  ]) {
    test('missing $field fails defensively', () {
      expect(
        () => parseProviderCompletion(completionJson()..remove(field)),
        throwsFormatException,
      );
    });
  }
  for (final invalid in [null, '75', -1, 101, double.nan, double.infinity]) {
    test('invalid percentage $invalid fails defensively', () {
      expect(
        () => parseProviderCompletion(
          completionJson()..['completionPercentage'] = invalid,
        ),
        throwsFormatException,
      );
    });
  }
  test('malformed service fields and root types are rejected', () {
    for (final input in [null, [], 'private']) {
      expect(() => parseProviderCompletion(input), throwsFormatException);
    }
    final fields =
        (completionJson()['services'] as List).single as Map<String, dynamic>;
    for (final key in fields.keys) {
      final json = completionJson();
      ((json['services'] as List).single as Map<String, dynamic>).remove(key);
      expect(
        () => parseProviderCompletion(json),
        throwsFormatException,
        reason: key,
      );
    }
    expect(
      () => parseProviderCompletion(
        completionJson()..['profileCompleted'] = 'true',
      ),
      throwsFormatException,
    );
    expect(
      () => parseProviderCompletion(completionJson()..['services'] = [null]),
      throwsFormatException,
    );
    final json = completionJson();
    ((json['services'] as List).single
            as Map<String, dynamic>)['assignmentId'] =
        1.5;
    expect(() => parseProviderCompletion(json), throwsFormatException);
  });

  late CompletionAdapter adapter;
  late ApiClient client;
  late FakeSessionStorage storage;
  late ProviderCompletionRepositoryImpl repository;
  setUp(() {
    adapter = CompletionAdapter();
    storage = FakeSessionStorage()..session = testSession();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      tokenProvider: SessionAccessTokenProvider(storage, now: () => testNow),
      adapter: adapter,
    );
    repository = ProviderCompletionRepositoryImpl(
      ProviderCompletionRemoteDataSource(client),
    );
  });
  tearDown(() => client.close(force: true));
  test(
    'GET completion opts into auth and existing session token bridge',
    () async {
      expect(
        await repository.loadCompletion(),
        isA<Success<ProviderCompletion>>(),
      );
      final request = adapter.request!;
      expect(request.method, 'GET');
      expect(request.path, '/providers/me/completion');
      expect(request.extra['bthere.network.requires_auth'], isTrue);
      expect(
        request.headers['Authorization'],
        'Bearer ${storage.session!.accessToken}',
      );
      expect(storage.reads, 1);
      expect(storage.writes, 0);
      expect(storage.clears, 0);
    },
  );
  test(
    'repository safely maps unsupported and malformed response failures',
    () async {
      adapter.body = completionJson(step: 'SECRET_NEW_STEP');
      final unsupported =
          await repository.loadCompletion() as Failure<ProviderCompletion>;
      expect(unsupported.failure.code, 'ONBOARDING_UNSUPPORTED_STEP');
      expect(unsupported.failure.message, isNot(contains('SECRET')));
      adapter.body = {'private': 'trace'};
      final malformed =
          await repository.loadCompletion() as Failure<ProviderCompletion>;
      expect(malformed.failure.code, 'ONBOARDING_INVALID_RESPONSE');
      expect(malformed.failure.cause, isNull);
    },
  );
  for (final status in [401, 500]) {
    test('HTTP $status maps safe failure without session mutation', () async {
      adapter.status = status;
      adapter.body = {'message': 'secret backend trace and token'};
      final result =
          await repository.loadCompletion() as Failure<ProviderCompletion>;
      expect(result.failure.message, isNot(contains('secret')));
      expect(result.failure.cause, isNull);
      expect(storage.clears, 0);
      expect(storage.writes, 0);
    });
  }
}
