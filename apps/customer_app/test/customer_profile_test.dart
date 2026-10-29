import 'dart:async';

import 'package:customer_app/features/profile/application/customer_profile_controller.dart';

import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:customer_app/features/auth/data/customer_auth_service.dart';
import 'package:customer_app/features/profile/data/customer_profile_repository.dart';
import 'package:customer_app/features/profile/data/customer_photo_upload.dart';
import 'package:customer_app/features/profile/domain/customer_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_auth_test.dart'
    show Fixture, customerProfileJson, openCustomerAccount;

CustomerProfileInput input() => const CustomerProfileInput(
  firstName: ' Jane ',
  lastName: ' Doe ',
  addressLine1: ' 10 Main Street ',
  city: ' Colombo ',
  country: ' Sri Lanka ',
  addressLine2: ' ',
  district: 'Colombo',
  province: 'Western',
  postalCode: '00100',
);

Future<void> signIn(WidgetTester tester, Fixture f) async {
  await f.pump(tester);
  await tester.enterText(
    find.byKey(const ValueKey('customer-identifier')),
    'test@example.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('customer-password')),
    'password-123',
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('customer-auth-submit')),
  );
  await tester.tap(find.byKey(const ValueKey('customer-auth-submit')));
  await tester.pumpAndSettle();
  await openCustomerAccount(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Public Sans')
      ..addFont(rootBundle.load('assets/fonts/PublicSans-Variable.ttf'));
    await loader.load();
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets(
      'single profile form exposes all fields and reachable save at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final f = Fixture();
        addTearDown(f.dispose);
        await signIn(tester, f);
        await tester.tap(find.text('Edit profile'));
        await tester.pumpAndSettle();
        expect(find.text('Edit your profile'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('customer-profile-photo')),
          findsOneWidget,
        );
        for (final pair in [
          ['firstName', 'lastName'],
          ['city', 'district'],
          ['province', 'postalCode'],
        ]) {
          final left = tester.getTopLeft(
            find.byKey(ValueKey('customer-profile-${pair[0]}')),
          );
          final right = tester.getTopLeft(
            find.byKey(ValueKey('customer-profile-${pair[1]}')),
          );
          expect(left.dy, right.dy);
          expect(right.dx, greaterThan(left.dx));
        }

        for (final field in input().toJson().keys.where(
          (key) => key != 'profilePhoto',
        )) {
          expect(
            find.byKey(ValueKey('customer-profile-$field')),
            findsOneWidget,
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-profile-save')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Save changes').hitTestable(), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
        expect(tester.takeException(), isNull);
        expect(f.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
      },
    );
  }
  test('late profile response after logout is ignored', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.controller.login('test', 'password');
    f.adapter.pendingProfile = Completer<void>();
    final controller = CustomerProfileController(
      CustomerProfileRepository(f.service),
      f.controller,
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.stage, CustomerProfileStage.loading);
    await f.controller.logout();
    f.adapter.pendingProfile!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.stage, CustomerProfileStage.idle);
    expect(controller.profile, isNull);
  });
  testWidgets(
    'registration verification sends missing-profile customer to name/address form',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.profileStatus = 404;
      await f.pump(tester);
      await tester.tap(find.byKey(const ValueKey('customer-register-tab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-identifier')),
        'test@example.com',
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
      expect(
        find.byKey(const ValueKey('customer-profile-firstName')),
        findsNothing,
      );
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
      expect(find.text('Let’s get to know you'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-profile-firstName')),
        findsOneWidget,
      );
      expect(
        f.adapter.requests
            .where((r) => r.path == '/customers/me/profile')
            .single
            .method,
        'GET',
      );
    },
  );
  testWidgets('profile form is scrollable with enlarged text and no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final f = Fixture();
    addTearDown(f.dispose);
    f.adapter.profileStatus = 404;
    await signIn(tester, f);
    await tester.ensureVisible(
      find.byKey(const ValueKey('customer-profile-save')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('customer-profile-firstName')),
    );
    final last = tester.getTopLeft(
      find.byKey(const ValueKey('customer-profile-lastName')),
    );
    expect(last.dy, greaterThan(first.dy));
    expect(last.dx, first.dx);
  });
  test(
    'profile request has exactly ten fields and no identity or provider fields',
    () {
      expect(input().toJson(), {
        'firstName': 'Jane',
        'lastName': 'Doe',
        'addressLine1': '10 Main Street',
        'city': 'Colombo',
        'country': 'Sri Lanka',
        'addressLine2': null,
        'district': 'Colombo',
        'province': 'Western',
        'postalCode': '00100',
        'profilePhoto': null,
      });
      expect(input().valid, isTrue);
      expect(
        const CustomerProfileInput(
          firstName: ' ',
          lastName: 'Doe',
          addressLine1: 'a',
          city: 'b',
          country: 'c',
        ).valid,
        isFalse,
      );
    },
  );
  test('profile parses documented IDs/nullable optional values and preserves full replacement fields', () {
    final json = customerProfileJson()
      ..['profilePhoto'] = 'https://cdn.example.invalid/saved.jpg';
    final value = CustomerProfile.fromJson(json);
    expect(value.customerId, 7);
    expect(value.userId, 12);
    expect(value.details.toJson()['addressLine2'], 'Unit 2');
    expect(value.details.profilePhoto, json['profilePhoto']);
    expect(
      () => CustomerProfile.fromJson({...json, 'profileCompleted': null}),
      throwsFormatException,
    );
  });
  test('authenticated GET and PUT preserve exact profile contract', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    final repo = CustomerProfileRepository(f.service);
    expect((await repo.load())?.details.firstName, 'Jane');
    final result = await repo.save(input());
    expect(result.details.firstName, 'Jane');
    final request = f.adapter.requests.last;
    expect(request.method, 'PUT');
    expect(request.path, '/customers/me/profile');
    expect(request.data, input().toJson());
    expect(request.headers['Authorization'], 'Bearer access-one');
  });
  for (final status in [404, 400, 403, 500]) {
    test(
      'profile GET $status ${status == 404 ? 'means missing' : 'remains an error'}',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        await f.service.login('test', 'password');
        f.adapter.profileStatus = status;
        final repo = CustomerProfileRepository(f.service);
        if (status == 404) {
          expect(await repo.load(), isNull);
        } else {
          await expectLater(repo.load(), throwsA(isA<CustomerAuthFailure>()));
        }
      },
    );
  }
  test('public image upload uses a single binary file part and returned public URL', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    final url = await uploadCustomerPhoto(
      f.service,
      Uint8List.fromList([255, 216, 255, 0]),
      'photo.jpg',
    );
    expect(url, 'https://cdn.example.invalid/returned.jpg');
    final request = f.adapter.requests.last;
    expect(request.path, '/uploads/images');
    expect(request.headers['Authorization'], 'Bearer access-one');
    final form = request.data as FormData;
    expect(form.files.length, 1);
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.contentType.toString(), 'image/jpeg');
    expect(form.fields, isEmpty);
  });
  test('photo validation blocks SVG and oversize files before HTTP; 413 is readable', () async {
    final f = Fixture();
    addTearDown(f.dispose);
    await f.service.login('test', 'password');
    await expectLater(
      uploadCustomerPhoto(
        f.service,
        Uint8List.fromList('<svg/>'.codeUnits),
        'photo.svg',
      ),
      throwsA(isA<CustomerAuthFailure>()),
    );
    await expectLater(
      uploadCustomerPhoto(
        f.service,
        Uint8List(10 * 1024 * 1024 + 1),
        'large.jpg',
      ),
      throwsA(isA<CustomerAuthFailure>()),
    );
    expect(
      f.adapter.requests.where((r) => r.path == '/uploads/images'),
      isEmpty,
    );
    f.adapter.uploadStatus = 413;
    await expectLater(
      uploadCustomerPhoto(
        f.service,
        Uint8List.fromList([255, 216, 255, 0]),
        'photo.jpg',
      ),
      throwsA(
        isA<CustomerAuthFailure>().having(
          (e) => e.message,
          'message',
          contains('10 MB'),
        ),
      ),
    );
  });
  test(
    'profile PUT 401 refreshes but never automatically replays the write',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await f.service.login('test', 'password');
      f.adapter.profilePutStatus = 401;
      await expectLater(
        CustomerProfileRepository(f.service).save(input()),
        throwsA(isA<CustomerAuthFailure>()),
      );
      expect(f.adapter.requests.where((r) => r.method == 'PUT').length, 1);
      expect(
        f.adapter.requests.where((r) => r.path == '/auth/refresh').length,
        1,
      );
    },
  );
  testWidgets(
    'missing profile routes to form; required values save and open account',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.profileStatus = 404;
      await signIn(tester, f);
      expect(find.text('Let’s get to know you'), findsOneWidget);
      expect(find.text('Gender'), findsNothing);
      expect(find.text('Date of birth'), findsNothing);
      for (final fields in [
        {'firstName': 'Test', 'lastName': 'Customer'},
        {'addressLine1': '10 Street', 'city': 'Colombo'},
        {'country': 'Sri Lanka'},
      ]) {
        for (final field in fields.entries) {
          await tester.enterText(
            find.byKey(ValueKey('customer-profile-${field.key}')),
            field.value,
          );
        }
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-profile-save')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-profile-save')));
      await tester.pumpAndSettle();
      await openCustomerAccount(tester);
      expect(find.text('Welcome, customer12'), findsOneWidget);
      expect(find.text('Your Customer profile is ready.'), findsOneWidget);
      expect(
        (f.adapter.requests.lastWhere((request) => request.method == 'PUT').data
            as Map)['firstName'],
        'Test',
      );
    },
  );
  testWidgets(
    'profile server error shows retry and never a blank completion form',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      f.adapter.profileStatus = 500;
      await signIn(tester, f);
      expect(find.text('Unable to load your profile'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('customer-profile-firstName')),
        findsNothing,
      );
      expect(find.text('Private profile error'), findsNothing);
      f.adapter.profileStatus = 200;
      await tester.tap(find.text('Retry profile'));
      await tester.pumpAndSettle();
      await openCustomerAccount(tester);
      expect(find.text('Welcome, customer12'), findsOneWidget);
    },
  );
  testWidgets(
    'edit restores optional fields; failed save retains draft and image URL',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await signIn(tester, f);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-profile-firstName')),
        'Changed',
      );
      expect(
        tester
            .widget<BThereTextField>(
              find.byKey(const ValueKey('customer-profile-addressLine2')),
            )
            .controller
            ?.text,
        'Unit 2',
      );
      f.adapter.profilePutStatus = 500;
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-profile-save')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-profile-save')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BThereTextField>(
              find.byKey(const ValueKey('customer-profile-firstName')),
            )
            .controller
            ?.text,
        'Changed',
      );
      expect(find.text('Edit your profile'), findsOneWidget);
      f.adapter.profilePutStatus = 200;
      await tester.ensureVisible(
        find.byKey(const ValueKey('customer-profile-save')),
      );
      await tester.tap(find.byKey(const ValueKey('customer-profile-save')));
      await tester.pumpAndSettle();
      await openCustomerAccount(tester);
      expect(find.text('Welcome, customer12'), findsOneWidget);
      expect((f.adapter.requests.last.data as Map)['addressLine2'], 'Unit 2');
    },
  );
}
