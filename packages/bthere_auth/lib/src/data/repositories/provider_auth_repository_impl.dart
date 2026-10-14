import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';

import '../../domain/models/auth_requests.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/models/otp_request_info.dart';
import '../../domain/repositories/provider_auth_repository.dart';
import '../models/auth_response.dart';
import '../services/provider_auth_remote_data_source.dart';

final class ProviderAuthRepositoryImpl implements ProviderAuthRepository {
  ProviderAuthRepositoryImpl({
    required ApiClient client,
    required SessionStorage sessionStorage,
    DateTime Function()? now,
  }) : _remote = ProviderAuthRemoteDataSource(client),
       _storage = sessionStorage,
       _now = now ?? DateTime.now;

  final ProviderAuthRemoteDataSource _remote;
  final SessionStorage _storage;
  final DateTime Function() _now;

  static const _invalidRequest = AppFailure(
    message: 'The authentication request is invalid.',
    code: 'AUTH_INVALID_REQUEST',
  );
  static const _invalidResponse = AppFailure(
    message: 'The server could not complete the request. Please try again.',
    code: 'AUTH_INVALID_RESPONSE',
  );

  @override
  Future<Result<AuthUser>> loginProvider({
    required String identifier,
    required String password,
  }) {
    if (identifier.trim().isEmpty || password.isEmpty) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _verify(() => _remote.login(identifier.trim(), password));
  }

  @override
  Future<Result<AuthUser>> authenticateProviderWithGoogle(String idToken) {
    if (idToken.trim().isEmpty) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _verify(() => _remote.authenticateGoogle(idToken));
  }

  @override
  Future<Result<RegistrationAccount>> registerProviderWithEmail(
    ProviderEmailRegistrationRequest request,
  ) {
    final length = request.password.runes.length;
    if (request.email.trim().isEmpty || length < 10 || length > 72) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _perform(
      () => _remote.register(request),
      conflictFailure: const AppFailure(
        message: 'This email is already registered. Sign in instead.',
        code: 'AUTH_EMAIL_ALREADY_REGISTERED',
      ),
    );
  }

  @override
  Future<Result<OtpRequestInfo>> requestProviderPhoneOtp(
    ProviderPhoneOtpRequest request,
  ) {
    if (request.phoneNumber.trim().isEmpty) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _perform(() => _remote.requestPhone(request));
  }

  @override
  Future<Result<AuthUser>> verifyProviderEmail(
    EmailOtpVerificationRequest request,
  ) {
    if (request.email.trim().isEmpty) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _verify(() => _remote.verifyEmail(request));
  }

  @override
  Future<Result<AuthUser>> verifyProviderPhoneOtp(
    ProviderPhoneOtpVerificationRequest request,
  ) {
    if (request.phoneNumber.trim().isEmpty) {
      return Future.value(const Failure(_invalidRequest));
    }
    return _verify(() => _remote.verifyPhone(request));
  }

  Future<Result<T>> _perform<T>(
    Future<T> Function() operation, {
    AppFailure? conflictFailure,
  }) async {
    try {
      return Success(await operation());
    } on NetworkException catch (error) {
      if (error.statusCode == 409 && conflictFailure != null) {
        return Failure(conflictFailure);
      }
      return Failure(error.toAppFailure());
    } on _WrongProviderRole {
      return const Failure(
        AppFailure(
          message: 'A Provider account is required.',
          code: 'AUTH_WRONG_ACCOUNT_TYPE',
        ),
      );
    } on _SessionPersistenceFailure {
      return const Failure(
        AppFailure(
          message: 'The session could not be saved.',
          code: 'SESSION_PERSIST_FAILED',
        ),
      );
    } on FormatException {
      return const Failure(_invalidResponse);
    } on ArgumentError {
      return const Failure(_invalidResponse);
    } catch (_) {
      // Never expose unexpected transport/parser/clock errors or raw causes.
      return const Failure(
        AppFailure(
          message: 'Authentication could not be completed.',
          code: 'AUTH_OPERATION_FAILED',
        ),
      );
    }
  }

  Future<Result<AuthUser>> _verify(
    Future<AuthTokenResponse> Function() fetch,
  ) => _perform(() async {
    final response = await fetch();
    if (!response.user.roles.contains(providerAccountType)) {
      throw const _WrongProviderRole();
    }
    final duration = Duration(seconds: response.expiresIn);
    if (duration.inSeconds != response.expiresIn) invalidAuthResponse();
    final session = AuthSession(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      tokenType: response.tokenType,
      expiresAt: _now().toUtc().add(duration),
      user: SessionUser(
        id: response.user.id,
        marketId: response.user.marketId,
        username: response.user.username,
        email: response.user.email,
        phoneNumber: response.user.phoneNumber,
        status: response.user.status,
        roles: response.user.roles,
        emailVerified: response.user.emailVerified,
        phoneVerified: response.user.phoneVerified,
      ),
    );
    try {
      await _storage.write(session);
    } catch (_) {
      throw const _SessionPersistenceFailure();
    }
    return response.user;
  });
}

final class _WrongProviderRole implements Exception {
  const _WrongProviderRole();
}

final class _SessionPersistenceFailure implements Exception {
  const _SessionPersistenceFailure();
}
