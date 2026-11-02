import 'package:bthere_network/bthere_network.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter/foundation.dart';

class CustomerAuthFailure implements Exception {
  const CustomerAuthFailure(this.message, {this.status, this.retryAt});
  final String message;
  final int? status;
  final DateTime? retryAt;
}

/// Customer-only contracts. No automatic replay of writes or Provider coupling.
class CustomerAuthService {
  CustomerAuthService(this.client, this.storage, {required this.now});
  final ApiClient client;
  final SessionStorage storage;
  final DateTime Function() now;
  Future<AuthSession>? _refreshing;
  int _generation = 0;
  Future<void> _persistence = Future.value();

  Future<void> _persist(AuthSession session, int generation) {
    final operation = _persistence.then((_) async {
      if (generation != _generation) {
        throw const CustomerAuthFailure('Please sign in again.');
      }
      await storage.write(session);
    });
    _persistence = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _clear() async {
    _generation++;
    await _persistence;
    await storage.clear();
  }

  Future<Response<Object?>> _post(
    String path,
    Map<String, Object?>? body, {
    String? token,
  }) async {
    Response<Object?> response;
    try {
      response = await client.post<Object?>(
        path,
        data: body,
        requiresAuth: token != null,
        options: Options(validateStatus: (_) => true),
      );
    } on NetworkException catch (failure) {
      if (kDebugMode && path.startsWith('/auth/otp/')) {
        debugPrint(
          'Customer phone auth: method=POST path=$path status=${failure.statusCode ?? 'unavailable'} outcome=${failure.kind.name}',
        );
      }
      rethrow;
    }
    if (kDebugMode && path.startsWith('/auth/otp/')) {
      debugPrint(
        'Customer phone auth: method=POST path=$path status=${response.statusCode ?? 'unavailable'} outcome=response',
      );
    }
    _check(response);
    return response;
  }

  void _check(Response<Object?> response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
    DateTime? retryAt;
    if (status == 429) {
      final body = response.data;
      final seconds = body is Map ? body['retryAfterSeconds'] : null;
      final header = response.headers.value('retry-after');
      final headerSeconds = int.tryParse(header ?? '');
      final waits = [
        if (seconds is int && seconds >= 0) seconds,
        if (headerSeconds != null && headerSeconds >= 0) headerSeconds,
      ];
      var wait = waits.isEmpty ? 60 : waits.reduce((a, b) => a > b ? a : b);
      // RFC HTTP-date Retry-After values are handled by the HTTP-date parser.
      final date = header == null ? null : _httpDate(header);
      if (date != null && date.difference(now()).inSeconds > wait) {
        wait = date.difference(now()).inSeconds + 1;
      }
      retryAt = now().add(Duration(seconds: wait));
    }
    throw CustomerAuthFailure(
      switch (status) {
        400 => 'Please check your details and try again.',
        401 => 'Your credentials or verification code are invalid or expired.',
        403 => 'This account cannot access the Customer app.',
        409 => 'This email is already registered. Sign in instead.',
        429 => 'Please wait before trying again.',
        _ => 'The server could not complete the request. Please try again.',
      },
      status: status,
      retryAt: retryAt,
    );
  }

  Future<void> register(String email, String password) async {
    final response = await _post('/auth/register', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'accountType': 'CUSTOMER',
    });
    if (response.statusCode != 201) {
      throw const FormatException('Invalid registration response');
    }
    final user = SessionUser.fromJson(response.data);
    if (!user.roles.contains('CUSTOMER')) {
      throw const CustomerAuthFailure('A Customer account is required.');
    }
  }

  Future<int> resend(String email) async {
    final response = await _post('/auth/email/resend', {
      'email': email.trim().toLowerCase(),
    });
    final data = response.data;
    if (response.statusCode != 202 ||
        data is! Map ||
        data['expiresIn'] is! int ||
        (data['expiresIn'] as int) <= 0) {
      throw const FormatException('Invalid OTP response');
    }
    return data['expiresIn'] as int;
  }

  Future<int> requestPhoneOtp(String phoneNumber) async {
    if (!validPhoneNumber(phoneNumber)) {
      throw const CustomerAuthFailure(
        'Enter a phone number with country code, for example +94771234567.',
      );
    }
    final response = await _post('/auth/otp/request', {
      'phoneNumber': phoneNumber.trim(),
      'accountType': 'CUSTOMER',
    });
    final data = response.data;
    if (response.statusCode != 202 ||
        data is! Map ||
        data['expiresIn'] is! int ||
        (data['expiresIn'] as int) <= 0) {
      throw const FormatException('Invalid phone OTP response');
    }
    return data['expiresIn'] as int;
  }

  Future<AuthSession> verifyPhoneOtp(String phoneNumber, String otp) async {
    if (!validPhoneNumber(phoneNumber) || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const CustomerAuthFailure(
        'Enter a valid phone number and six-digit code.',
      );
    }
    return _authenticate('/auth/otp/verify', {
      'phoneNumber': phoneNumber.trim(),
      'otp': otp,
      'accountType': 'CUSTOMER',
    });
  }

  Future<AuthSession> login(String identifier, String password) =>
      _authenticate('/auth/login', {
        'identifier': identifier.trim(),
        'password': password,
      });
  Future<AuthSession> verify(String email, String otp) => _authenticate(
    '/auth/email/verify',
    {'email': email.trim().toLowerCase(), 'otp': otp},
  );

  Future<AuthSession> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    final generation = _generation;
    final response = await _post(path, body);
    final session = _parseSession(response.data);
    if (generation != _generation) {
      throw const CustomerAuthFailure('Please sign in again.');
    }
    await _persist(session, generation);
    return session;
  }

  AuthSession _parseSession(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Invalid session');
    }
    final access = body['accessToken'],
        refresh = body['refreshToken'],
        expires = body['expiresIn'];
    if (access is! String ||
        access.trim().isEmpty ||
        refresh is! String ||
        refresh.trim().isEmpty ||
        body['tokenType'] != 'Bearer' ||
        expires is! int ||
        expires <= 0) {
      throw const FormatException('Invalid session');
    }
    final user = _customer(body['user']);
    final duration = Duration(seconds: expires);
    if (duration.inSeconds != expires) {
      throw const FormatException('Invalid session expiry');
    }
    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      tokenType: 'Bearer',
      expiresAt: now().toUtc().add(duration),
      user: user,
    );
  }

  SessionUser _customer(Object? body) {
    final user = SessionUser.fromJson(body);
    if (!user.roles.contains('CUSTOMER') || user.status != 'ACTIVE') {
      throw const CustomerAuthFailure(
        'An active Customer account is required.',
        status: 403,
      );
    }
    return user;
  }

  Future<AuthSession> refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;
    final operation = _rotate();
    _refreshing = operation;
    return operation.whenComplete(() {
      if (identical(_refreshing, operation)) _refreshing = null;
    });
  }

  Future<AuthSession> _rotate() async {
    final old = await storage.read();
    if (old == null) {
      throw const CustomerAuthFailure('Please sign in again.', status: 401);
    }
    try {
      return await _authenticate('/auth/refresh', {
        'refreshToken': old.refreshToken,
      });
    } on CustomerAuthFailure catch (error) {
      if (error.status == 401 || error.status == 403) {
        await _clear();
      }
      rethrow;
    }
  }

  /// Safe authenticated read; retries once after a serialized token refresh.
  Future<Response<Object?>> get(String path) async {
    var session = await storage.read();
    if (session == null) {
      throw const CustomerAuthFailure('Please sign in again.', status: 401);
    }
    if (session.isExpiredAt(now())) session = await refresh();
    Future<Response<Object?>> fetch(AuthSession session) => client.get<Object?>(
      path,
      requiresAuth: true,
      options: Options(validateStatus: (_) => true),
    );
    var response = await fetch(session);
    if (response.statusCode == 401) {
      final latest = await storage.read();
      session =
          latest != null &&
              latest.accessToken != session.accessToken &&
              !latest.isExpiredAt(now())
          ? latest
          : await refresh();
      response = await fetch(session);
    }
    if (response.statusCode == 401) await _clear();
    _check(response);
    return response;
  }

  Future<SessionUser?> restore() async {
    var session = await storage.read();
    if (session == null) return null;
    if (session.isExpiredAt(now())) session = await refresh();
    final generation = _generation;
    final response = await get('/users/me');
    final user = _customer(response.data);
    final latest = await storage.read();
    if (latest == null || generation != _generation) return null;
    await _persist(
      AuthSession(
        accessToken: latest.accessToken,
        refreshToken: latest.refreshToken,
        tokenType: latest.tokenType,
        expiresAt: latest.expiresAt,
        user: user,
      ),
      generation,
    );
    return user;
  }

  /// Refresh before a profile write, but never automatically replay the write.
  Future<Response<Object?>> put(String path, Map<String, Object?> data) async {
    final session = await storage.read();
    if (session == null) {
      throw const CustomerAuthFailure('Please sign in again.', status: 401);
    }
    if (session.isExpiredAt(now())) await refresh();
    final response = await client.put<Object?>(
      path,
      data: data,
      requiresAuth: true,
      options: Options(validateStatus: (_) => true),
    );
    if (response.statusCode == 401) {
      await refresh();
      throw const CustomerAuthFailure(
        'Your session was renewed. Please save again.',
      );
    }
    _check(response);
    return response;
  }

  Future<Response<Object?>> uploadImage(FormData data) async {
    final session = await storage.read();
    if (session == null) {
      throw const CustomerAuthFailure('Please sign in again.', status: 401);
    }
    if (session.isExpiredAt(now())) await refresh();
    final response = await client.post<Object?>(
      '/uploads/images',
      data: data,
      requiresAuth: true,
      options: Options(
        contentType: 'multipart/form-data',
        validateStatus: (_) => true,
      ),
    );
    if (response.statusCode == 401) {
      await refresh();
      throw const CustomerAuthFailure(
        'Your session was renewed. Please upload again.',
      );
    }
    if (response.statusCode == 413) {
      throw const CustomerAuthFailure(
        'Choose a profile photo no larger than 10 MB.',
      );
    }
    _check(response);
    return response;
  }

  /// Booking APIs retain their problem details for feature-specific handling.
  /// Only safe reads/searches may be replayed after an explicit 401.
  Future<Response<Object?>> bookingRequest(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? headers,
    bool safeRead = false,
  }) async {
    var session = await storage.read();
    if (session == null) {
      throw const CustomerAuthFailure('Please sign in again.', status: 401);
    }
    if (session.isExpiredAt(now())) session = await refresh();
    Future<Response<Object?>> send() {
      final options = Options(validateStatus: (_) => true, headers: headers);
      return switch (method) {
        'GET' => client.get<Object?>(
          path,
          requiresAuth: true,
          options: options,
        ),
        'POST' => client.post<Object?>(
          path,
          data: data,
          requiresAuth: true,
          options: options,
        ),
        'PUT' => client.put<Object?>(
          path,
          data: data,
          requiresAuth: true,
          options: options,
        ),
        _ => throw ArgumentError('Unsupported booking request method'),
      };
    }

    var response = await send();
    if (response.statusCode == 401) {
      final current = await storage.read();
      if (current?.accessToken == session.accessToken) await refresh();
      if (!safeRead) {
        throw const CustomerAuthFailure(
          'Your session was renewed. Please try again.',
          status: 401,
        );
      }
      response = await send();
      if (response.statusCode == 401) {
        await _clear();
        throw const CustomerAuthFailure('Please sign in again.', status: 401);
      }
    }
    return response;
  }

  Future<void> logout({bool all = false}) async {
    _generation++;
    final session = await storage.read();
    if (session != null) {
      var current = session;
      if (all && current.isExpiredAt(now())) current = await refresh();
      final response = await _post(
        all ? '/auth/logout-all' : '/auth/logout',
        all ? null : {'refreshToken': current.refreshToken},
        token: all ? current.accessToken : null,
      );
      if (response.statusCode != 204) {
        throw const FormatException('Invalid logout response');
      }
    }
    await _clear();
  }
}

DateTime? _httpDate(String text) {
  final match = RegExp(
    r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(text);
  if (match == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months.indexOf(match[2]!) + 1;
  if (month == 0) return null;
  return DateTime.utc(
    int.parse(match[3]!),
    month,
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
}

bool validPhoneNumber(String value) =>
    RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value.trim());
