import 'dart:async';

import 'package:bthere_auth/bthere_auth.dart';
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/core/session/app_session_state.dart';
import 'package:provider_app/features/auth/application/email_registration_controller.dart';
import 'package:provider_app/features/auth/application/email_verification_controller.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_session_storage.dart';

void main() {
  late FakeAuthRepository repo;
  late FakeSessionStorage storage;
  late ProviderContainer container;
  setUp(() {
    repo = FakeAuthRepository();
    storage = FakeSessionStorage();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        providerAuthRepositoryProvider.overrideWithValue(repo),
        sessionStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(() => testNow),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'verification completion after disposal does not update state or throw',
    () async {
      final listener = container.listen(
        emailVerificationControllerProvider,
        (_, _) {},
      );
      repo.pendingVerification = Completer<Result<AuthUser>>();
      final request = container
          .read(emailVerificationControllerProvider.notifier)
          .submit(email: 'provider@example.com', otp: '123456');
      listener.close();
      await container.pump();
      repo.pendingVerification!.complete(Success(testAuthUser));
      await request;
      expect(storage.reads, 0);
    },
  );

  for (final success in [true, false]) {
    test(
      'registration idle → loading → ${success ? 'success' : 'failure'}, duplicate blocked',
      () async {
        container.listen(emailRegistrationControllerProvider, (_, _) {});
        repo.pendingRegistration = Completer<Result<RegistrationAccount>>();
        expect(
          container.read(emailRegistrationControllerProvider).loading,
          isFalse,
        );
        expect(
          container.read(emailRegistrationControllerProvider).value,
          isNull,
        );
        final controller = container.read(
          emailRegistrationControllerProvider.notifier,
        );
        final request = controller.submit(
          email: ' provider@example.com ',
          password: '1234567890',
        );
        expect(
          container.read(emailRegistrationControllerProvider).loading,
          isTrue,
        );
        await controller.submit(
          email: 'ignored@example.com',
          password: 'ignored',
        );
        expect(repo.registrations, 1);
        expect(repo.registrationRequest!.email, 'provider@example.com');
        final failure = AppFailure(
          message: 'Please try again.',
          code: 'EXPECTED',
          cause: StateError('private'),
        );
        repo.pendingRegistration!.complete(
          success ? Success(testRegistration) : Failure(failure),
        );
        final value = await request;
        final state = container.read(emailRegistrationControllerProvider);
        expect(state.loading, isFalse);
        expect(state.value, success ? same(testRegistration) : isNull);
        expect(value, success ? same(testRegistration) : isNull);
        if (!success) {
          expect(state.failure!.message, failure.message);
          expect(state.failure!.code, failure.code);
          expect(state.failure!.cause, isNull);
        }
        expect(storage.writes, 0);
        expect(storage.reads, 0);
      },
    );
  }
  for (final success in [true, false]) {
    test(
      'verification idle → loading → ${success ? 'success with local refresh' : 'failure without refresh'}',
      () async {
        container.listen(emailVerificationControllerProvider, (_, _) {});
        container.listen(appSessionStateProvider, (_, _) {});
        expect(
          await container.read(appSessionStateProvider.future),
          AppSessionState.unauthenticated,
        );
        repo.pendingVerification = Completer<Result<AuthUser>>();
        repo.persistVerifiedSession = () => storage.write(testSession());
        expect(
          container.read(emailVerificationControllerProvider).value,
          isNull,
        );
        final controller = container.read(
          emailVerificationControllerProvider.notifier,
        );
        final request = controller.submit(
          email: 'provider@example.com',
          otp: ' 123456 ',
        );
        expect(
          container.read(emailVerificationControllerProvider).loading,
          isTrue,
        );
        await controller.submit(email: 'ignored@example.com', otp: 'ignored');
        expect(repo.verifications, 1);
        expect(repo.verificationRequest!.email, 'provider@example.com');
        expect(repo.verificationRequest!.otp, '123456');
        repo.pendingVerification!.complete(
          success
              ? Success(testAuthUser)
              : const Failure(
                  AppFailure(
                    message: 'Code could not be verified.',
                    code: 'EXPECTED',
                  ),
                ),
        );
        await request;
        final state = container.read(emailVerificationControllerProvider);
        expect(state.loading, isFalse);
        expect(state.value, success ? same(testAuthUser) : isNull);
        expect(
          await container.read(appSessionStateProvider.future),
          success
              ? AppSessionState.authenticated
              : AppSessionState.unauthenticated,
        );
        expect(storage.reads, success ? 2 : 1);
        expect(storage.writes, success ? 1 : 0);
      },
    );
  }
  test(
    'unexpected registration exception becomes safe retryable failure',
    () async {
      container.listen(emailRegistrationControllerProvider, (_, _) {});
      repo.throwRegistration = true;
      await container
          .read(emailRegistrationControllerProvider.notifier)
          .submit(email: 'provider@example.com', password: '1234567890');
      final state = container.read(emailRegistrationControllerProvider);
      expect(state.loading, isFalse);
      expect(state.failure!.message, isNot(contains('private')));
      expect(state.failure!.cause, isNull);
      repo.throwRegistration = false;
      await container
          .read(emailRegistrationControllerProvider.notifier)
          .submit(email: 'provider@example.com', password: '1234567890');
      expect(
        container.read(emailRegistrationControllerProvider).value,
        isNotNull,
      );
    },
  );
  test(
    'unexpected verification exception is safe and does not restore session',
    () async {
      container.listen(emailVerificationControllerProvider, (_, _) {});
      repo.throwVerification = true;
      await container
          .read(emailVerificationControllerProvider.notifier)
          .submit(email: 'provider@example.com', otp: '123456');
      final state = container.read(emailVerificationControllerProvider);
      expect(state.loading, isFalse);
      expect(state.failure!.cause, isNull);
      expect(state.failure!.message, isNot(contains('private')));
      expect(storage.reads, 0);
    },
  );
  test(
    'registration completion after disposal cannot update UI or throw',
    () async {
      final listener = container.listen(
        emailRegistrationControllerProvider,
        (_, _) {},
      );
      repo.pendingRegistration = Completer<Result<RegistrationAccount>>();
      final request = container
          .read(emailRegistrationControllerProvider.notifier)
          .submit(email: 'provider@example.com', password: '1234567890');
      listener.close();
      await container.pump();
      repo.pendingRegistration!.complete(Success(testRegistration));
      expect(await request, isNull);
    },
  );
  test('verification success without readable valid credentials never claims authentication', () async {
    container.listen(emailVerificationControllerProvider, (_, _) {});
    container.listen(appSessionStateProvider, (_, _) {});
    await container.read(appSessionStateProvider.future);
    // Contract violation simulated by fake: app still trusts local restoration.
    await container
        .read(emailVerificationControllerProvider.notifier)
        .submit(email: 'provider@example.com', otp: '123456');
    expect(
      await container.read(appSessionStateProvider.future),
      AppSessionState.unauthenticated,
    );
  });
}
