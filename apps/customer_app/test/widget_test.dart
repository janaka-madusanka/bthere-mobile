import 'package:customer_app/app/customer_app.dart';
import 'package:customer_app/app/customer_config.dart';
import 'package:customer_app/app/customer_providers.dart';
import 'package:bthere_session/bthere_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing config performs no storage or API calls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerConfigProvider.overrideWithValue(null),
          customerSessionStorageProvider.overrideWith(
            (ref) => throw StateError('Unexpected storage'),
          ),
          customerApiClientProvider.overrideWith(
            (ref) => throw StateError('Unexpected API'),
          ),
        ],
        child: const CustomerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to start'), findsOneWidget);
  });
  test('configuration validates prefix and release HTTPS', () {
    for (final value in [
      '',
      'https://example.com',
      'https://example.com/api/v1?token=x',
      'https://user:pass@example.com/api/v1',
      ' https://example.com/api/v1',
    ]) {
      expect(() => CustomerConfig(apiBaseUrl: value), throwsFormatException);
    }
    expect(
      () => CustomerConfig(
        apiBaseUrl: 'http://localhost:8080/api/v1',
        allowHttp: false,
      ),
      throwsFormatException,
    );
    expect(
      CustomerConfig(apiBaseUrl: 'https://example.com/api/v1').apiBaseUrl,
      'https://example.com/api/v1',
    );
  });
  for (final role in ['CUSTOMER', 'SERVICE_PROVIDER', 'missing']) {
    for (final expired in [true, false]) {
      test('token bridge role=$role expired=$expired', () async {
        final now = DateTime.utc(2030);
        final session = AuthSession(
          accessToken: 'synthetic-access',
          refreshToken: 'synthetic-refresh',
          tokenType: 'Bearer',
          expiresAt: now.add(Duration(seconds: expired ? 0 : 60)),
          user: role == 'missing'
              ? null
              : SessionUser(
                  id: 1,
                  username: 'test',
                  status: 'ACTIVE',
                  roles: [role],
                ),
        );
        final token = await CustomerAccessTokenProvider(
          _Storage(session),
          now: () => now,
        ).getAccessToken();
        expect(
          token,
          role == 'CUSTOMER' && !expired ? 'synthetic-access' : null,
        );
      });
    }
  }
  test(
    'missing session supplies no token; storage failures propagate',
    () async {
      expect(
        await CustomerAccessTokenProvider(
          _Storage(null),
          now: DateTime.now,
        ).getAccessToken(),
        isNull,
      );
      expect(
        CustomerAccessTokenProvider(
          _Storage(null, fail: true),
          now: DateTime.now,
        ).getAccessToken(),
        throwsStateError,
      );
    },
  );
}

class _Storage implements SessionStorage {
  _Storage(this.session, {this.fail = false});
  final AuthSession? session;
  final bool fail;
  @override
  Future<AuthSession?> read() async {
    if (fail) throw StateError('Storage unavailable');
    return session;
  }

  @override
  Future<void> clear() async => throw UnimplementedError();
  @override
  Future<void> write(AuthSession value) async => throw UnimplementedError();
}
