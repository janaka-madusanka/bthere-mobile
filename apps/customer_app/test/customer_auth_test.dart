import 'customer_test_map.dart';

import 'package:customer_app/features/booking/application/customer_booking_controller.dart';

import 'dart:async';
import 'dart:convert';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/customer_config.dart';
import 'package:customer_app/app/customer_providers.dart';
import 'package:customer_app/features/auth/application/customer_auth_controller.dart';
import 'package:customer_app/features/auth/data/customer_auth_service.dart';
import 'package:customer_app/features/discovery/application/customer_discovery_controller.dart';
import 'package:customer_app/features/discovery/data/customer_market_selection_store.dart';
import 'package:customer_app/features/booking/presentation/booking_location_picker.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final clock = DateTime.utc(2030, 1, 1);
Map<String, Object?> account({
  String role = 'CUSTOMER',
  String? email = 'test@example.com',
}) => {
  'id': 12,
  'username': 'customer12',
  'email': email,
  'status': 'ACTIVE',
  'marketId': null,
  'roles': [role],
};
Map<String, Object?> tokens({
  String role = 'CUSTOMER',
  String suffix = 'one',
}) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'tokenType': 'Bearer',
  'expiresIn': 123,
  'user': account(role: role),
};

class MemorySession implements SessionStorage {
  AuthSession? value;
  bool failRead = false, failWrite = false;
  int writes = 0, clears = 0;
  @override
  Future<AuthSession?> read() async {
    if (failRead) throw StateError('private storage error');
    return value;
  }

  @override
  Future<void> write(AuthSession session) async {
    if (failWrite) throw StateError('private write error');
    writes++;
    value = session;
  }

  @override
  Future<void> clear() async {
    clears++;
    value = null;
  }
}

class LocalAdapter implements HttpClientAdapter {
  Future<ResponseBody?> Function(RequestOptions)? extraHandler;
  final requests = <RequestOptions>[];
  int refreshStatus = 200, resendStatus = 202, userStatus = 200;
  String role = 'CUSTOMER';
  Object? loginBody;
  Object? marketsBody;
  int marketsStatus = 200, servicesStatus = 200;
  final serviceBodies = <int, Object?>{};
  final pendingServices = <int, Completer<void>>{};
  int optionsStatus = 200;
  final optionBodies = <String, Object?>{};
  final pendingOptions = <String, Completer<void>>{};
  bool phoneOnly = false;
  int phoneRequestStatus = 202, phoneVerifyStatus = 200;
  Completer<void>? pendingPhone;
  int profileStatus = 200, profilePutStatus = 200, uploadStatus = 201;
  Object? profileBody;
  Map<String, Object?> savedProfile = customerProfileJson();
  Completer<void>? pendingProfile;
  Completer<void>? pendingRefresh, pendingLogin;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final extra = await extraHandler?.call(options);
    if (extra != null) return extra;
    Object? body;
    var status = 200;
    switch (Uri.parse(options.path).path) {
      case '/customers/me/bookings':
        body = [];
      case '/markets':
        status = marketsStatus;
        body = marketsBody ?? [marketJson()];
      case '/customers/me/services':
        final marketId = int.parse(options.uri.queryParameters['marketId']!);
        await pendingServices[marketId]?.future;
        status = servicesStatus;
        body = serviceBodies[marketId] ?? [serviceJson()];
      case '/auth/register':
        status = 201;
        body = {...account(), 'status': 'PENDING'};
      case '/auth/login':
        await pendingLogin?.future;
        body = loginBody ?? tokens(role: role);
      case '/auth/otp/request':
        await pendingPhone?.future;
        status = phoneRequestStatus;
        body = status == 429 ? {'retryAfterSeconds': 90} : {'expiresIn': 300};
      case '/auth/otp/verify':
        status = phoneVerifyStatus;
        body = {
          ...tokens(role: role),
          'user': account(
            role: role,
            email: phoneOnly ? null : 'test@example.com',
          ),
        };
      case '/auth/email/verify':
        body = tokens(role: role);
      case '/auth/email/resend':
        status = resendStatus;
        body = status == 429
            ? {'retryAfterSeconds': 90, 'detail': 'private'}
            : {'expiresIn': 300};
      case '/auth/refresh':
        await pendingRefresh?.future;
        status = refreshStatus;
        body = tokens(suffix: 'two');
      case '/users/me':
        status = userStatus;
        body = account(
          role: role,
          email: phoneOnly ? null : 'test@example.com',
        );
      case '/safe-read':
        if (options.headers['Authorization'] == 'Bearer access-one') {
          status = 401;
        }
        body = {};
      case '/customers/me/profile':
        await pendingProfile?.future;
        status = options.method == 'PUT' ? profilePutStatus : profileStatus;
        if (options.method == 'PUT' && status == 200) {
          savedProfile = {
            ...customerProfileJson(),
            ...Map<String, Object?>.from(options.data as Map),
          };
        }
        body =
            profileBody ??
            (status == 200
                ? savedProfile
                : {'detail': 'Private profile error'});
      case '/uploads/images':
        status = uploadStatus;
        body = {
          'key': 'providers/12/images/returned.jpg',
          'url': 'https://cdn.example.invalid/returned.jpg',
          'contentType': 'image/jpeg',
          'size': 4,
        };
      case '/auth/logout':
      case '/auth/logout-all':
        status = 204;
      case final path
          when RegExp(r'^/customers/me/services/\d+/options$').hasMatch(path):
        final serviceId = int.parse(path.split('/')[4]);
        final marketId = options.uri.queryParameters['marketId'];
        final key = '$marketId/$serviceId';
        await pendingOptions[key]?.future;
        status = optionsStatus;
        body = optionBodies[key] ?? [optionJson(serviceId: serviceId)];
      default:
        throw StateError('Unexpected endpoint');
    }
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (status == 429) 'retry-after': ['120'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> customerProfileJson() => {
  'customerId': 7,
  'userId': 12,
  'firstName': 'Jane',
  'lastName': 'Doe',
  'profilePhoto': null,
  'addressLine1': '10 Main Street',
  'addressLine2': 'Unit 2',
  'city': 'Colombo',
  'district': 'Colombo',
  'province': 'Western',
  'postalCode': '00100',
  'country': 'Sri Lanka',
  'status': 'ACTIVE',
  'profileCompleted': true,
};

Map<String, Object?> marketJson({
  int id = 1,
  String name = 'Sri Lanka',
  String country = 'LK',
}) => {
  'id': id,
  'name': name,
  'countryCode': country,
  'currencyCode': country == 'LK' ? 'LKR' : 'USD',
  'timezone': country == 'LK' ? 'Asia/Colombo' : 'Etc/UTC',
  'locale': 'en',
  'phoneCode': '+94',
  'status': 'ACTIVE',
};
Map<String, Object?> serviceJson({
  int id = 3,
  String name = 'Nursing',
  String status = 'ELIGIBLE',
}) => {
  'service': {
    'id': id,
    'name': name,
    'description': 'Home nursing services',
    'iconUrl': null,
    'status': 'ACTIVE',
    'icon': null,
    'coverImage': null,
    'gallery': [],
    'responsibilities': [],
  },
  'access': {
    'status': status,
    'action': status == 'ELIGIBLE' ? 'CONTINUE' : 'VIEW_REQUIREMENTS',
    'eligibility': {'eligible': status == 'ELIGIBLE', 'reasons': []},
  },
};
Map<String, Object?> optionJson({
  int id = 12,
  int serviceId = 3,
  String name = 'Home Care',
  String access = 'ELIGIBLE',
  int order = 1,
}) => {
  'option': {
    'optionId': id,
    'serviceTypeId': serviceId,
    'name': name,
    'description': 'Care at your location',
    'displayOrder': order,
    'status': 'ACTIVE',
    'icon': null,
    'coverImage': null,
  },
  'access': {
    'status': access,
    'action': access == 'ELIGIBLE' ? 'CONTINUE' : 'VIEW_REQUIREMENTS',
    'eligibility': {'eligible': access == 'ELIGIBLE', 'reasons': []},
  },
};

Future<void> openCustomerAccount(WidgetTester tester) async {
  final continueButton = find.byKey(const ValueKey('customer-market-continue'));
  if (continueButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-home-account')));
    await tester.pumpAndSettle();
  }
}

class MemoryMarketValues implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failRead = false, failWrite = false;
  Completer<void>? pendingRead, pendingWrite;
  @override
  Future<String?> read(String key) async {
    await pendingRead?.future;
    if (failRead) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await pendingWrite?.future;
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class Fixture {
  bool autoAvailability = false;
  final storage = MemorySession(), adapter = LocalAdapter();
  final marketValues = MemoryMarketValues();
  late final marketStore = CustomerMarketSelectionStore(
    marketValues,
    apiScope: 'https://example.invalid/api/v1',
  );
  late final client = ApiClient(
    config: NetworkConfig(baseUrl: 'https://example.invalid/api/v1'),
    adapter: adapter,
    tokenProvider: CustomerAccessTokenProvider(storage, now: () => clock),
  );
  late final service = CustomerAuthService(client, storage, now: () => clock);
  late final controller = CustomerAuthController(service);
  void dispose() {
    controller.dispose();
    client.close(force: true);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerAutoAvailabilityEnabledProvider.overrideWithValue(
            autoAvailability,
          ),
          customerConfigProvider.overrideWithValue(
            CustomerConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
          ),
          customerClockProvider.overrideWithValue(() => clock),
          customerSessionStorageProvider.overrideWithValue(storage),
          customerApiClientProvider.overrideWithValue(client),
          customerMarketSelectionStoreProvider.overrideWithValue(marketStore),
          customerMapBuilderProvider.overrideWithValue(CustomerTestMap.new),
          customerDeviceLocationProvider.overrideWithValue(
            () async => const GeoPoint(6.9271, 79.8612),
          ),
        ],
        child: const CustomerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Viewport-fit assertions must measure the actual shipped font, not Ahem.
    final loader = FontLoader('Public Sans')
      ..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'));
    await loader.load();
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('login fits without scrolling at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final f = Fixture();
      addTearDown(f.dispose);
      await f.pump(tester);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      expect(find.text('Be there when care is matter'), findsOneWidget);
      final google = tester.getRect(
        find.byKey(const ValueKey('customer-social-google')),
      );
      final apple = tester.getRect(
        find.byKey(const ValueKey('customer-social-apple')),
      );
      expect(google.left, apple.left);
      expect(google.width, apple.width);
      expect(apple.top, greaterThan(google.bottom));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('customer-auth-submit')))
            .bottom,
        lessThan(size.height - 24),
      );
      expect(find.text('Privacy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'keyboard keeps sign-in action reachable through overflow scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final f = Fixture();
      addTearDown(f.dispose);
      await f.pump(tester);
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const ValueKey('customer-auth-submit')))
            .bottom,
        lessThanOrEqualTo(500),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unverified email can resume verification without registering again',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.pump(tester);
      await tester.enterText(
        find.byKey(const ValueKey('customer-identifier')),
        'TEST@example.com',
      );
      await tester.ensureVisible(find.text('Verify email'));
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();
      expect(find.text('Verify your email'), findsOneWidget);
      expect(f.adapter.requests.single.path, '/auth/email/resend');
      expect(f.adapter.requests.single.data, {'email': 'test@example.com'});
      expect(f.storage.value, isNull);
    },
  );
  test(
    'resend exact public email payload and successful server expiry',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      expect(await f.service.resend(' TEST@example.com '), 300);
      expect(f.adapter.requests.single.data, {'email': 'test@example.com'});
      expect(f.adapter.requests.single.headers['Authorization'], isNull);
    },
  );

  test(
    'controller registration and OTP validation block invalid requests',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.controller.restore();
      await f.controller.register('invalid', 'short');
      expect(f.adapter.requests, isEmpty);
      await f.controller.register('test@example.com', 'password-123');
      expect(f.controller.verificationEmail, 'test@example.com');
      await f.controller.verify('123');
      await f.controller.resend();
      expect(f.adapter.requests.length, 1);
      expect(f.storage.value, isNull);
    },
  );

  test('startup storage failure and current user server errors remain retryable failures', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.storage.failRead = true;
    await f.controller.restore();
    expect(f.controller.stage, CustomerAuthStage.failure);
    expect(f.controller.error, isNot(contains('private')));
    f.storage.failRead = false;
    await f.service.login('test', 'password');
    f.adapter.userStatus = 500;
    await f.controller.restore();
    expect(f.controller.stage, CustomerAuthStage.failure);
    expect(f.storage.value, isNotNull);
    f.adapter.userStatus = 200;
    await f.controller.restore();
    expect(f.controller.stage, CustomerAuthStage.authenticated);
  });

  test(
    'current user role mismatch never enters authenticated account',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      f.adapter.role = 'SERVICE_PROVIDER';
      await f.controller.restore();
      expect(f.controller.stage, CustomerAuthStage.failure);
      expect(f.controller.user, isNull);
    },
  );

  test('repeated safe-read 401 clears session after one refresh', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    f.adapter.userStatus = 401;
    await f.controller.restore();
    expect(
      f.adapter.requests.where((r) => r.path == '/auth/refresh').length,
      1,
    );
    expect(f.storage.value, isNull);
    expect(f.controller.stage, CustomerAuthStage.signedOut);
  });

  test(
    'logout prevents a late refresh from resurrecting the session',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      f.adapter.pendingRefresh = Completer<void>();
      final pending = f.service.refresh();
      final expectation = expectLater(
        pending,
        throwsA(isA<CustomerAuthFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      await f.service.logout();
      f.adapter.pendingRefresh!.complete();
      await expectation;
      expect(f.storage.value, isNull);
    },
  );
  test(
    'registration exact CUSTOMER payload, normalized email, no session',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.register(' Test@Example.com ', ' password-123 ');
      final request = f.adapter.requests.single;
      expect(request.data, {
        'email': 'test@example.com',
        'password': ' password-123 ',
        'accountType': 'CUSTOMER',
      });
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(f.storage.value, isNull);
    },
  );
  test('login exact identifier, unchanged password, secure expiry and nullable email', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.loginBody = {...tokens(), 'user': account(email: null)};
    await f.service.login(' test ', ' password ');
    expect(f.adapter.requests.single.data, {
      'identifier': 'test',
      'password': ' password ',
    });
    expect(f.storage.value?.expiresAt, clock.add(const Duration(seconds: 123)));
    expect(f.storage.value?.user?.email, isNull);
  });
  test('OTP preserves leading zeros and has no accountType', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.verify(' TEST@example.com ', '001234');
    expect(f.adapter.requests.single.data, {
      'email': 'test@example.com',
      'otp': '001234',
    });
    expect(f.storage.value, isNotNull);
  });
  test('wrong role and malformed tokens never persist', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.role = 'SERVICE_PROVIDER';
    await expectLater(
      f.service.login('test', 'password'),
      throwsA(isA<CustomerAuthFailure>()),
    );
    expect(f.storage.writes, 0);
    f.adapter.loginBody = {...tokens(), 'expiresIn': 0};
    await expectLater(
      f.service.login('test', 'password'),
      throwsFormatException,
    );
    expect(f.storage.writes, 0);
  });
  test('429 honors longest cooldown without exposing backend body', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.resendStatus = 429;
    await expectLater(
      f.service.resend('test@example.com'),
      throwsA(
        isA<CustomerAuthFailure>()
            .having(
              (e) => e.retryAt,
              'deadline',
              clock.add(const Duration(seconds: 120)),
            )
            .having(
              (e) => e.message,
              'safe message',
              'Please wait before trying again.',
            ),
      ),
    );
  });
  test('concurrent refresh rotates once and saves both tokens', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    f.adapter.pendingRefresh = Completer<void>();
    final pending = [f.service.refresh(), f.service.refresh()];
    await Future<void>.delayed(Duration.zero);
    f.adapter.pendingRefresh!.complete();
    await Future.wait(pending);
    expect(
      f.adapter.requests.where((r) => r.path == '/auth/refresh').length,
      1,
    );
    expect(f.storage.value?.accessToken, 'access-two');
    expect(f.storage.value?.refreshToken, 'refresh-two');
  });
  test(
    'refresh 401 clears credentials; server failure retains credentials',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      f.adapter.refreshStatus = 500;
      await expectLater(
        f.service.refresh(),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(f.storage.value, isNotNull);
      f.adapter.refreshStatus = 401;
      await expectLater(
        f.service.refresh(),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(f.storage.value, isNull);
    },
  );
  test(
    'concurrent unauthorized safe reads refresh once and retry with bearer',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      await Future.wait([
        f.service.get('/safe-read'),
        f.service.get('/safe-read'),
      ]);
      expect(
        f.adapter.requests.where((r) => r.path == '/auth/refresh').length,
        1,
      );
      expect(
        f.adapter.requests.last.headers['Authorization'],
        'Bearer access-two',
      );
    },
  );
  test('restore expired session rotates and validates users/me', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    final old = f.storage.value!;
    f.storage.value = AuthSession(
      accessToken: old.accessToken,
      refreshToken: old.refreshToken,
      tokenType: old.tokenType,
      expiresAt: clock,
      user: old.user,
    );
    expect((await f.service.restore())?.username, 'customer12');
    expect(f.adapter.requests.last.path, '/users/me');
  });
  for (final all in [false, true]) {
    test('logout all=$all handles 204 and clears local session', () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      await f.service.logout(all: all);
      final r = f.adapter.requests.last;
      expect(r.path, all ? '/auth/logout-all' : '/auth/logout');
      expect(r.data, all ? null : {'refreshToken': 'refresh-one'});
      expect(r.headers['Authorization'], all ? 'Bearer access-one' : null);
      expect(f.storage.value, isNull);
    });
  }
  test('controller blocks duplicate login and never enters account after persistence failure', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.pendingLogin = Completer<void>();
    final pending = f.controller.login('test', 'password');
    await f.controller.login('test', 'password');
    f.storage.failWrite = true;
    f.adapter.pendingLogin!.complete();
    await pending;
    expect(f.adapter.requests.length, 1);
    expect(f.controller.stage, isNot(CustomerAuthStage.authenticated));
    expect(f.controller.error, isNot(contains('private')));
  });
  test('missing session starts signed out without network requests', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.controller.restore();
    expect(f.controller.stage, CustomerAuthStage.signedOut);
    expect(f.adapter.requests, isEmpty);
  });
  testWidgets(
    'register then verify enters authenticated handoff; sign out returns to sign in',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.pump(tester);
      await tester.tap(find.byKey(const ValueKey('customer-register-tab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-identifier')),
        'TEST@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-password')),
        'password-123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-confirm')),
        'password-123',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Verify your email'), findsOneWidget);
      expect(f.storage.value, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('customer-otp')),
        '001234',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Email verified!'), findsOneWidget);
      expect(f.storage.value, isNotNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.tap(
        find.byKey(const ValueKey('customer-verification-success-continue')),
      );
      await tester.pumpAndSettle();
      await openCustomerAccount(tester);
      expect(find.text('Welcome, customer12'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customer-login-tab')), findsOneWidget);
      expect(f.storage.value, isNull);
    },
  );
  testWidgets(
    'narrow large-text auth screen has no overflow; invalid inputs send no requests',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await f.pump(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-auth-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
      await tester.pumpAndSettle();
      expect(f.adapter.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
