import 'dart:convert';
import 'dart:typed_data';

import 'package:bthere_network/bthere_network.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  late FakeAdapter adapter;
  late FakeTokenProvider tokens;
  late ApiClient client;
  setUp(() {
    adapter = FakeAdapter();
    tokens = FakeTokenProvider();
    client = ApiClient(
      config: NetworkConfig(
        baseUrl: 'https://example.invalid/api/v1',
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 9),
      ),
      tokenProvider: tokens,
      adapter: adapter,
    );
  });
  tearDown(() => client.close());

  test('applies base URL, timeouts, Accept, and no redirects', () async {
    await client.get<Map<String, dynamic>>('/items');
    final request = adapter.requests.single;
    expect(request.uri.toString(), 'https://example.invalid/api/v1/items');
    expect(request.connectTimeout, const Duration(seconds: 7));
    expect(request.receiveTimeout, const Duration(seconds: 8));
    expect(request.sendTimeout, const Duration(seconds: 9));
    expect(request.headers['Accept'], 'application/json');
    expect(request.followRedirects, isFalse);
  });

  for (final base in [
    '',
    'relative',
    'ftp://example.invalid',
    'https://',
    'https://user:secret@example.invalid',
    'https://example.invalid?key=value',
    'https://example.invalid/#fragment',
    ' https://example.invalid',
  ]) {
    test('rejects invalid base URL case ${base.hashCode}', () {
      expect(() => NetworkConfig(baseUrl: base), throwsArgumentError);
    });
  }
  test('rejects nonpositive timeout and supplies defaults', () {
    expect(
      NetworkConfig(baseUrl: 'https://example.invalid').connectTimeout,
      const Duration(seconds: 20),
    );
    expect(
      () => NetworkConfig(
        baseUrl: 'https://example.invalid',
        sendTimeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test(
    'authenticated requests obtain current token on every request',
    () async {
      await client.get<Object?>('/private', requiresAuth: true);
      expect(
        adapter.requests.last.headers['Authorization'] ==
            'Bearer ${tokens.token}',
        isTrue,
      );
      tokens.token = 'different-synthetic-token';
      await client.get<Object?>('/private', requiresAuth: true);
      expect(
        adapter.requests.last.headers['Authorization'] ==
            'Bearer ${tokens.token}',
        isTrue,
      );
      expect(tokens.calls, 2);
    },
  );
  for (final token in <String?>[null, '', '   ']) {
    test(
      'unavailable token case ${token?.length} adds no Authorization',
      () async {
        tokens.token = token;
        await client.get<Object?>(
          '/private',
          requiresAuth: true,
          options: Options(headers: {'authorization': 'stale'}),
        );
        expect(
          adapter.requests.single.headers.keys.any(
            (key) => key.toLowerCase() == 'authorization',
          ),
          isFalse,
        );
      },
    );
  }
  test(
    'public requests skip provider and strip manually supplied auth',
    () async {
      await client.get<Object?>(
        '/public',
        options: Options(
          headers: {'Authorization': 'stale'},
          extra: {'context': 'test'},
        ),
      );
      expect(tokens.calls, 0);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(adapter.requests.single.extra['context'], 'test');
    },
  );
  test(
    'authenticated request works without a provider and sends no header',
    () async {
      final noProvider = ApiClient(
        config: NetworkConfig(baseUrl: 'https://example.invalid'),
        adapter: adapter,
      );
      addTearDown(noProvider.close);
      await noProvider.get<Object?>('/private', requiresAuth: true);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );
  test('provider failure is normalized and never reaches transport', () async {
    tokens.fail = true;
    await expectLater(
      client.get<Object?>('/private', requiresAuth: true),
      throwsA(
        isA<NetworkException>().having(
          (e) => e.kind,
          'kind',
          NetworkExceptionKind.unknown,
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
  test('rejects token header injection', () async {
    tokens.token = 'synthetic\r\nInjected: value';
    await expectLater(
      client.get<Object?>('/private', requiresAuth: true),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    'rejects absolute/cross-origin API paths before requesting credentials',
    () async {
      await expectLater(
        client.get<Object?>(
          'https://other.invalid/private',
          requiresAuth: true,
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(tokens.calls, 0);
      expect(adapter.requests, isEmpty);
    },
  );

  for (final method in ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test(
      '$method forwards path, query, body, options and typed response',
      () async {
        final options = Options(headers: {'X-Example': 'safe'}, method: 'HEAD');
        const query = {'page': 2};
        const body = {'name': 'sample'};
        final Response<Map<String, dynamic>> response;
        switch (method) {
          case 'GET':
            response = await client.get(
              '/items',
              queryParameters: query,
              options: options,
            );
          case 'POST':
            response = await client.post(
              '/items',
              queryParameters: query,
              data: body,
              options: options,
            );
          case 'PUT':
            response = await client.put(
              '/items',
              queryParameters: query,
              data: body,
              options: options,
            );
          case 'PATCH':
            response = await client.patch(
              '/items',
              queryParameters: query,
              data: body,
              options: options,
            );
          default:
            response = await client.delete(
              '/items',
              queryParameters: query,
              data: body,
              options: options,
            );
        }
        final request = adapter.requests.single;
        expect(request.method, method);
        expect(request.path, '/items');
        expect(request.queryParameters, query);
        expect(request.data, method == 'GET' ? isNull : body);
        expect(request.headers['X-Example'], 'safe');
        expect(options.method, 'HEAD');
        expect(options.extra, isNull);
        expect(response.data, {'ok': true});
      },
    );
  }
  test('accepts caller-created multipart without reading files', () async {
    final data = FormData.fromMap({
      'label': 'sample',
      'file': MultipartFile.fromBytes([1, 2, 3], filename: 'sample.bin'),
    });
    await client.post<Object?>('/upload', data: data);
    expect(adapter.requests.single.data, same(data));
    expect(
      adapter.requests.single.contentType,
      startsWith('multipart/form-data'),
    );
    expect(adapter.bytesReceived, isNotEmpty);
  });

  final failures = {
    DioExceptionType.connectionTimeout: NetworkExceptionKind.timeout,
    DioExceptionType.sendTimeout: NetworkExceptionKind.timeout,
    DioExceptionType.receiveTimeout: NetworkExceptionKind.timeout,
    DioExceptionType.transformTimeout: NetworkExceptionKind.timeout,
    DioExceptionType.connectionError: NetworkExceptionKind.connection,
    DioExceptionType.badCertificate: NetworkExceptionKind.connection,
    DioExceptionType.cancel: NetworkExceptionKind.cancelled,
    DioExceptionType.unknown: NetworkExceptionKind.unknown,
  };
  for (final entry in failures.entries) {
    test('normalizes ${entry.key.name}', () async {
      adapter.errorType = entry.key;
      await expectLater(
        client.get<Object?>('/items'),
        throwsA(
          isA<NetworkException>().having((e) => e.kind, 'kind', entry.value),
        ),
      );
    });
  }
  test(
    'pre-cancelled request is normalized without a transport request',
    () async {
      final cancel = CancelToken()..cancel('synthetic cancel');
      await expectLater(
        client.get<Object?>('/items', cancelToken: cancel),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.kind,
            'kind',
            NetworkExceptionKind.cancelled,
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  for (final status in [400, 401, 404, 500]) {
    test('normalizes HTTP $status without refresh or retry', () async {
      adapter.status = status;
      adapter.body = {'message': 'Invalid request', 'code': 'BAD_REQUEST'};
      await expectLater(
        client.post<Object?>('/items', data: {'value': 1}, requiresAuth: true),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.kind, 'kind', NetworkExceptionKind.badResponse)
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.message, 'message', 'Invalid request')
              .having((e) => e.backendCode, 'code', 'BAD_REQUEST'),
        ),
      );
      expect(adapter.requests.length, 1);
      expect(tokens.calls, 1);
    });
  }
  for (final body in <Object?>[
    null,
    'unexpected',
    [],
    {
      'message': ['wrong'],
      'code': 42,
    },
    {
      'error': {'details': 'unexpected'},
    },
  ]) {
    test(
      'unexpected error body case ${body.runtimeType} uses fallback',
      () async {
        adapter.status = 500;
        adapter.body = body;
        await expectLater(
          client.get<Object?>('/items'),
          throwsA(
            isA<NetworkException>()
                .having(
                  (e) => e.message,
                  'safe fallback',
                  'The server could not complete the request.',
                )
                .having((e) => e.backendCode, 'code', isNull),
          ),
        );
      },
    );
  }
  test('malformed JSON error body is normalized rather than leaked', () async {
    adapter.status = 500;
    adapter.rawBody = '{broken';
    await expectLater(
      client.get<Object?>('/items'),
      throwsA(isA<NetworkException>()),
    );
  });
  test(
    'error metadata and AppFailure never echo auth or sensitive body text',
    () async {
      adapter.status = 401;
      adapter.body = {
        'message': 'Bearer ${tokens.token}',
        'code': tokens.token,
      };
      try {
        await client.get<Object?>('/private', requiresAuth: true);
        fail('Expected a normalized failure');
      } on NetworkException catch (error) {
        final failure = error.toAppFailure();
        expect(error.message.contains(tokens.token!), isFalse);
        expect(error.toString().contains(tokens.token!), isFalse);
        expect(error.backendCode, isNull);
        expect(failure.message.contains(tokens.token!), isFalse);
        expect(failure.code, 'NETWORK_BADRESPONSE');
        expect(failure.cause, isNull);
      }
    },
  );
  test('maps safe backend code into AppFailure', () {
    const error = NetworkException(
      kind: NetworkExceptionKind.badResponse,
      message: 'Unauthorized',
      statusCode: 401,
      backendCode: 'UNAUTHORIZED',
    );
    final failure = error.toAppFailure();
    expect(failure.message, 'Unauthorized');
    expect(failure.code, 'UNAUTHORIZED');
    expect(failure.cause, isNull);
  });
}

class FakeTokenProvider implements AccessTokenProvider {
  String? token = 'synthetic-access-token';
  int calls = 0;
  bool fail = false;
  @override
  Future<String?> getAccessToken() async {
    calls++;
    if (fail) throw StateError('Synthetic provider failure');
    return token;
  }
}

class FakeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bytesReceived = <int>[];
  int status = 200;
  Object? body = {'ok': true};
  String? rawBody;
  DioExceptionType? errorType;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (errorType != null) {
      throw DioException(
        requestOptions: options,
        type: errorType!,
        message: 'Untrusted raw exception message',
      );
    }
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytesReceived.addAll(chunk);
      }
    }
    return ResponseBody.fromString(
      rawBody ?? jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
