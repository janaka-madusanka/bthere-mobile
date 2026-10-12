import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_test/flutter_test.dart';

const email = 'provider@example.invalid';
const phone = '+94764233731';
const password = 'SyntheticPassword123!';
const otp = 'synthetic-otp';

Map<String, Object?> userJson({bool registration = false}) => {
  'id': 25,
  'username': 'provider',
  'email': email,
  'phoneNumber': null,
  'status': registration ? 'PENDING' : 'ACTIVE',
  'roles': ['SERVICE_PROVIDER'],
  if (registration) 'emailVerified': false,
  if (registration) 'phoneVerified': false,
};

Map<String, Object?> tokenJson() => {
  'accessToken': 'synthetic-access',
  'refreshToken': 'synthetic-refresh',
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'user': userJson(),
};

void main() {
  final now = DateTime.utc(2030, 1, 2, 12);
  late FakeAdapter transport;
  late FakeSessionStorage storage;
  late ThrowingTokenProvider tokenProvider;
  late ApiClient client;
  late ProviderAuthRepository repository;
  setUp(() {
    transport = FakeAdapter();
    storage = FakeSessionStorage();
    tokenProvider = ThrowingTokenProvider();
    client = ApiClient(
      config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
      adapter: transport,
      tokenProvider: tokenProvider,
    );
    repository = ProviderAuthRepositoryImpl(
      client: client,
      sessionStorage: storage,
      now: () => now,
    );
  });
  tearDown(() => client.close());

  for (final credentials in [('', password), ('   ', password), (email, '')]) {
    test(
      'login rejects blank credential case ${credentials.$1.isEmpty
          ? 'empty identifier'
          : credentials.$2.isEmpty
          ? 'password'
          : 'whitespace identifier'}',
      () async {
        final result = await repository.loginProvider(
          identifier: credentials.$1,
          password: credentials.$2,
        );
        expect((result as Failure).failure.code, 'AUTH_INVALID_REQUEST');
        expect(transport.requests, isEmpty);
        expect(storage.writes, 0);
      },
    );
  }
  test('login accepts username and short password unchanged, trims identifier only', () async {
    transport.body = tokenJson();
    expect(
      (await repository.loginProvider(
        identifier: ' provider-name ',
        password: ' p ',
      )).isSuccess,
      isTrue,
    );
    expect(transport.requests.single.data, {
      'identifier': 'provider-name',
      'password': ' p ',
    });
  });
  test(
    'registration conflict has safe sign-in guidance and writes no session',
    () async {
      transport.status = 409;
      transport.body = {
        'message': 'synthetic-password synthetic-access private',
      };
      final result = await repository.registerProviderWithEmail(
        const ProviderEmailRegistrationRequest(
          email: email,
          password: password,
        ),
      );
      final failure = (result as Failure<RegistrationAccount>).failure;
      expect(failure.code, 'AUTH_EMAIL_ALREADY_REGISTERED');
      expect(
        failure.message,
        'This email is already registered. Sign in instead.',
      );
      expect(failure.cause, isNull);
      expect(storage.writes, 0);
    },
  );
  test('login conflict is not misclassified as a registered email', () async {
    transport.status = 409;
    transport.body = {'message': 'private'};
    final result = await repository.loginProvider(
      identifier: email,
      password: password,
    );
    final failure = (result as Failure<AuthUser>).failure;
    expect(failure.code, isNot('AUTH_EMAIL_ALREADY_REGISTERED'));
    expect(failure.message, isNot(contains('private')));
    expect(storage.writes, 0);
  });

  test('login success waits for secure persistence', () async {
    transport.body = tokenJson();
    storage.gate = Completer<void>();
    var completed = false;
    final operation = repository
        .loginProvider(identifier: email, password: password)
        .then((value) {
          completed = true;
          return value;
        });
    await storage.started.future;
    expect(completed, isFalse);
    storage.gate!.complete();
    expect((await operation).isSuccess, isTrue);
  });

  test('Google rejects blank ID token without network or storage', () async {
    final result = await repository.authenticateProviderWithGoogle('   ');
    expect((result as Failure).failure.code, 'AUTH_INVALID_REQUEST');
    expect(transport.requests, isEmpty);
    expect(storage.writes, 0);
  });

  test(
    'Google waits for secure persistence before returning success',
    () async {
      transport.body = tokenJson();
      storage.gate = Completer<void>();
      var completed = false;
      final operation = repository
          .authenticateProviderWithGoogle('synthetic-google-id')
          .then((value) {
            completed = true;
            return value;
          });
      await storage.started.future;
      expect(completed, isFalse);
      expect(storage.session, isNull);
      storage.gate!.complete();
      expect((await operation).isSuccess, isTrue);
    },
  );

  Future<Result<AuthUser>> verify(
    bool phoneFlow, {
    bool googleFlow = false,
    bool loginFlow = false,
  }) => loginFlow
      ? repository.loginProvider(identifier: email, password: password)
      : googleFlow
      ? repository.authenticateProviderWithGoogle('synthetic-google-id')
      : phoneFlow
      ? repository.verifyProviderPhoneOtp(
          const ProviderPhoneOtpVerificationRequest(
            phoneNumber: phone,
            otp: otp,
          ),
        )
      : repository.verifyProviderEmail(
          const EmailOtpVerificationRequest(email: email, otp: otp),
        );

  void expectPublicPost(String path) {
    expect(transport.requests.length, 1);
    final request = transport.requests.single;
    expect(request.method, 'POST');
    expect(request.path, path);
    expect(request.uri.toString(), 'https://example.invalid/api/v1$path');
    expect(
      request.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
      isFalse,
    );
    expect(tokenProvider.calls, 0);
  }

  test(
    'registration parses account, posts fixed Provider type, writes no session',
    () async {
      transport.status = 201;
      transport.body = userJson(registration: true);
      final result = await repository.registerProviderWithEmail(
        const ProviderEmailRegistrationRequest(
          email: email,
          password: password,
        ),
      );
      expect(result, isA<Success<RegistrationAccount>>());
      final account = (result as Success<RegistrationAccount>).value;
      expect(account.id, 25);
      expect(account.username, 'provider');
      expect(account.email, email);
      expect(account.phoneNumber, isNull);
      expect(account.status, 'PENDING');
      expect(account.emailVerified, isFalse);
      expect(account.phoneVerified, isFalse);
      expect(account.roles, ['SERVICE_PROVIDER']);
      expect(() => account.roles.add('ADMIN'), throwsUnsupportedError);
      expectPublicPost('/auth/register');
      final data = transport.requests.single.data as Map;
      expect(data['email'], email);
      expect(data['password'] == password, isTrue);
      expect(data['accountType'], 'SERVICE_PROVIDER');
      expect(data.keys.toSet(), {'email', 'password', 'accountType'});
      expect(storage.writes, 0);
      expect(storage.reads, 0);
      expect(storage.clears, 0);
    },
  );
  for (final length in [9, 10, 72, 73]) {
    test('registration password boundary $length', () async {
      transport.status = 201;
      transport.body = userJson(registration: true);
      final result = await repository.registerProviderWithEmail(
        ProviderEmailRegistrationRequest(email: email, password: 'x' * length),
      );
      expect(result.isSuccess, length >= 10 && length <= 72);
      expect(transport.requests.length, length >= 10 && length <= 72 ? 1 : 0);
      expect(storage.writes, 0);
      if (result is Failure<RegistrationAccount>) {
        expect(result.failure.code, 'AUTH_INVALID_REQUEST');
      }
    });
  }
  test('blank email fails locally', () async {
    final result = await repository.registerProviderWithEmail(
      const ProviderEmailRegistrationRequest(email: ' ', password: password),
    );
    expect((result as Failure).failure.code, 'AUTH_INVALID_REQUEST');
    expect(transport.requests, isEmpty);
  });
  for (var index = 0; index < 5; index++) {
    test(
      'invalid registration response case $index returns safe failure',
      () async {
        transport.status = index == 4 ? 200 : 201;
        transport.body = switch (index) {
          0 => null,
          1 => [],
          2 => {'id': 'invalid'},
          3 => userJson(registration: true)..remove('emailVerified'),
          _ => userJson(registration: true),
        };
        final result = await repository.registerProviderWithEmail(
          const ProviderEmailRegistrationRequest(
            email: email,
            password: password,
          ),
        );
        expect((result as Failure).failure.code, 'AUTH_INVALID_RESPONSE');
        expect(storage.writes, 0);
      },
    );
  }

  for (final label in ['email', 'phone', 'google', 'login']) {
    final phoneFlow = label == 'phone';
    final googleFlow = label == 'google';
    final loginFlow = label == 'login';
    test(
      '$label verification persists UTC expiry and returns safe user',
      () async {
        transport.body = tokenJson();
        final result = await verify(
          phoneFlow,
          googleFlow: googleFlow,
          loginFlow: loginFlow,
        );
        expect(result, isA<Success<AuthUser>>());
        final user = (result as Success<AuthUser>).value;
        expect(user.id, 25);
        expect(user.status, 'ACTIVE');
        expect(user.emailVerified, isNull);
        expect(user.phoneVerified, isNull);
        expect(user.roles, ['SERVICE_PROVIDER']);
        expectPublicPost(
          loginFlow
              ? '/auth/login'
              : googleFlow
              ? '/auth/google'
              : phoneFlow
              ? '/auth/otp/verify'
              : '/auth/email/verify',
        );
        final data = transport.requests.single.data as Map;
        if (loginFlow) {
          expect(data, {'identifier': email, 'password': password});
        } else if (googleFlow) {
          expect(data, {
            'idToken': 'synthetic-google-id',
            'type': 'SERVICE_PROVIDER',
          });
        } else {
          expect(
            data[phoneFlow ? 'phoneNumber' : 'email'],
            phoneFlow ? phone : email,
          );
          expect(data['otp'] == otp, isTrue);
        }
        expect(data.containsKey('accountType'), phoneFlow);
        if (phoneFlow) expect(data['accountType'], 'SERVICE_PROVIDER');
        expect(storage.writes, 1);
        final session = storage.session!;
        expect(session.expiresAt, now.add(const Duration(seconds: 900)));
        expect(session.expiresAt.isUtc, isTrue);
        expect(session.accessToken == 'synthetic-access', isTrue);
        expect(session.refreshToken == 'synthetic-refresh', isTrue);
        expect(session.tokenType, 'Bearer');
        expect(session.user!.id, user.id);
        expect(session.user!.username, user.username);
        expect(session.user!.email, user.email);
        expect(session.user!.status, user.status);
        expect(session.user!.roles, user.roles);
        expect(user.toString().contains(session.accessToken), isFalse);
        expect(user.toString().contains(session.refreshToken), isFalse);
        expect(storage.reads, 0);
        expect(storage.clears, 0);
      },
    );
    for (final roles in <List<String>>[
      [],
      ['CUSTOMER'],
      ['ADMIN'],
    ]) {
      test('$label rejects non-Provider role set ${roles.join(',')}', () async {
        transport.body = tokenJson()
          ..['user'] = (userJson()..['roles'] = roles);
        final result = await verify(
          phoneFlow,
          googleFlow: googleFlow,
          loginFlow: loginFlow,
        );
        expect((result as Failure).failure.code, 'AUTH_WRONG_ACCOUNT_TYPE');
        expect(storage.writes, 0);
      });
    }
    test('$label does not invent account status policy', () async {
      transport.body = tokenJson()
        ..['user'] = (userJson()..['status'] = 'BACKEND_STATUS');
      final result = await verify(
        phoneFlow,
        googleFlow: googleFlow,
        loginFlow: loginFlow,
      );
      expect((result as Success<AuthUser>).value.status, 'BACKEND_STATUS');
      expect(storage.writes, 1);
    });
    test(
      '$label session failure yields failure without secret/cause leakage',
      () async {
        transport.body = tokenJson();
        storage.fail = true;
        final result = await verify(
          phoneFlow,
          googleFlow: googleFlow,
          loginFlow: loginFlow,
        );
        final failure = (result as Failure).failure;
        expect(failure.code, 'SESSION_PERSIST_FAILED');
        expect(failure.message.contains('synthetic-access'), isFalse);
        expect(failure.message.contains('synthetic-refresh'), isFalse);
        expect(failure.cause, isNull);
        expect(storage.session, isNull);
      },
    );
    for (final field in [
      'accessToken',
      'refreshToken',
      'tokenType',
      'expiresIn',
      'user',
    ]) {
      test(
        '$label missing token response $field yields failure without storage',
        () async {
          transport.body = tokenJson()..remove(field);
          final result = await verify(
            phoneFlow,
            googleFlow: googleFlow,
            loginFlow: loginFlow,
          );
          expect((result as Failure).failure.code, 'AUTH_INVALID_RESPONSE');
          expect(storage.writes, 0);
        },
      );
    }
    final invalidValues = <Object?>[
      null,
      '',
      0,
      -1,
      1.5,
      '900',
      9223372036854775807,
    ];
    for (var index = 0; index < invalidValues.length; index++) {
      test('$label invalid expiry case $index yields safe failure', () async {
        transport.body = tokenJson()..['expiresIn'] = invalidValues[index];
        final result = await verify(
          phoneFlow,
          googleFlow: googleFlow,
          loginFlow: loginFlow,
        );
        expect((result as Failure).failure.code, 'AUTH_INVALID_RESPONSE');
        expect(storage.writes, 0);
      });
    }
    for (var index = 0; index < 5; index++) {
      test(
        '$label malformed user/credentials case $index is not persisted',
        () async {
          transport.body = switch (index) {
            0 => tokenJson()..['accessToken'] = ' ',
            1 => tokenJson()..['refreshToken'] = 42,
            2 => tokenJson()..['user'] = (userJson()..['roles'] = [42]),
            3 =>
              tokenJson()..['user'] = (userJson()..['emailVerified'] = 'false'),
            _ => [],
          };
          final result = await verify(
            phoneFlow,
            googleFlow: googleFlow,
            loginFlow: loginFlow,
          );
          expect((result as Failure).failure.code, 'AUTH_INVALID_RESPONSE');
          expect(storage.writes, 0);
        },
      );
    }
  }
  test('verification waits for persistence before returning success', () async {
    transport.body = tokenJson();
    storage.gate = Completer<void>();
    var completed = false;
    final operation = verify(false).then((value) {
      completed = true;
      return value;
    });
    await storage.started.future;
    expect(completed, isFalse);
    storage.gate!.complete();
    expect((await operation).isSuccess, isTrue);
  });
  test('clock offset converts to UTC in Auth only', () async {
    transport.body = tokenJson();
    repository = ProviderAuthRepositoryImpl(
      client: client,
      sessionStorage: storage,
      now: () => DateTime.parse('2030-01-02T17:30:00+05:30'),
    );
    expect((await verify(false)).isSuccess, isTrue);
    expect(storage.session!.expiresAt, now.add(const Duration(seconds: 900)));
  });
  test(
    'phone-created account can omit email and preserve phone metadata',
    () async {
      transport.body = tokenJson()
        ..['user'] = (userJson()
          ..remove('email')
          ..['phoneNumber'] = phone
          ..['phoneVerified'] = true);
      final result = await verify(true);
      final user = (result as Success<AuthUser>).value;
      expect(user.email, isNull);
      expect(user.phoneNumber, phone);
      expect(user.phoneVerified, isTrue);
    },
  );

  test('phone OTP request posts fixed account type, parses 202, never writes session', () async {
    transport.status = 202;
    transport.body = {
      'message': 'If eligible, an OTP has been sent',
      'expiresIn': 300,
    };
    final result = await repository.requestProviderPhoneOtp(
      const ProviderPhoneOtpRequest(phoneNumber: phone),
    );
    final info = (result as Success<OtpRequestInfo>).value;
    expect(info.message, 'If eligible, an OTP has been sent');
    expect(info.expiresIn, 300);
    expect(info.validity, const Duration(seconds: 300));
    expectPublicPost('/auth/otp/request');
    expect(transport.requests.single.data, {
      'phoneNumber': phone,
      'accountType': 'SERVICE_PROVIDER',
    });
    expect(storage.writes, 0);
  });
  for (var index = 0; index < 4; index++) {
    test('phone OTP request invalid response case $index', () async {
      transport.status = index == 3 ? 200 : 202;
      transport.body = switch (index) {
        0 => null,
        1 => {'message': 42, 'expiresIn': 300},
        2 => {'message': 'Sent', 'expiresIn': '300'},
        _ => {'message': 'Sent', 'expiresIn': 300},
      };
      final result = await repository.requestProviderPhoneOtp(
        const ProviderPhoneOtpRequest(phoneNumber: phone),
      );
      expect((result as Failure).failure.code, 'AUTH_INVALID_RESPONSE');
      expect(storage.writes, 0);
    });
  }
  test(
    'blank phone values and email verification email fail before network',
    () async {
      expect(
        (await repository.requestProviderPhoneOtp(
          const ProviderPhoneOtpRequest(phoneNumber: ' '),
        )).isFailure,
        isTrue,
      );
      expect(
        (await repository.verifyProviderPhoneOtp(
          const ProviderPhoneOtpVerificationRequest(phoneNumber: ' ', otp: otp),
        )).isFailure,
        isTrue,
      );
      expect(
        (await repository.verifyProviderEmail(
          const EmailOtpVerificationRequest(email: ' ', otp: otp),
        )).isFailure,
        isTrue,
      );
      expect(transport.requests, isEmpty);
    },
  );
  test('does not invent local OTP format or regional phone rules', () async {
    transport.body = tokenJson();
    final result = await repository.verifyProviderPhoneOtp(
      const ProviderPhoneOtpVerificationRequest(
        phoneNumber: 'backend-validates-this',
        otp: '',
      ),
    );
    expect(result.isSuccess, isTrue);
    expect((transport.requests.single.data as Map)['otp'], '');
  });
  final operations = <Future<Result<Object?>> Function()>[
    () => repository.registerProviderWithEmail(
      const ProviderEmailRegistrationRequest(email: email, password: password),
    ),
    () => verify(false),
    () => repository.requestProviderPhoneOtp(
      const ProviderPhoneOtpRequest(phoneNumber: phone),
    ),
    () => verify(true),
    () => repository.authenticateProviderWithGoogle('synthetic-google-id'),
    () => repository.loginProvider(identifier: email, password: password),
  ];
  for (var index = 0; index < operations.length; index++) {
    test(
      'operation $index maps network failure without leaking secrets',
      () async {
        transport.status = 401;
        transport.body = {
          'message': 'synthetic-access synthetic-refresh',
          'code': 'untrusted',
        };
        final result = await operations[index]();
        final failure = (result as Failure).failure;
        expect(failure.code, 'NETWORK_BADRESPONSE');
        expect(failure.cause, isNull);
        expect(failure.message.contains('synthetic-access'), isFalse);
        expect(failure.message.contains('synthetic-refresh'), isFalse);
        expect(storage.writes, 0);
        expect(storage.clears, 0);
        expect(transport.requests.length, 1);
      },
    );
  }
  test('request/domain toString does not print credentials', () {
    final values = [
      const ProviderEmailRegistrationRequest(email: email, password: password),
      const EmailOtpVerificationRequest(email: email, otp: otp),
      const ProviderPhoneOtpVerificationRequest(phoneNumber: phone, otp: otp),
    ];
    for (final value in values) {
      expect(value.toString().contains(password), isFalse);
      expect(value.toString().contains(otp), isFalse);
    }
  });
}

class ThrowingTokenProvider implements AccessTokenProvider {
  int calls = 0;
  @override
  Future<String?> getAccessToken() async {
    calls++;
    throw StateError('Public auth must not look up credentials');
  }
}

class FakeSessionStorage implements SessionStorage {
  AuthSession? session;
  int writes = 0;
  int reads = 0;
  int clears = 0;
  bool fail = false;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> write(AuthSession value) async {
    writes++;
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic-access synthetic-refresh');
    session = value;
  }

  @override
  Future<AuthSession?> read() async {
    reads++;
    return session;
  }

  @override
  Future<void> clear() async {
    clears++;
    session = null;
  }
}

class FakeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object? body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
