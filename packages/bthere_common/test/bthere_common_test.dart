import 'package:test/test.dart';

import 'package:bthere_common/bthere_common.dart';

void main() {
  test('success exposes its typed value and state', () {
    const result = Success<int>(42);
    expect(result.value, 42);
    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
  });
  test('failure retains the supplied failure and state', () {
    const error = AppFailure(message: 'Operation failed');
    const result = Failure<int>(error);
    expect(result.failure, same(error));
    expect(result.isSuccess, isFalse);
    expect(result.isFailure, isTrue);
  });
  test(
    'failure optional values default to null and retain supplied values',
    () {
      const minimal = AppFailure(message: 'Unavailable');
      expect(minimal.message, 'Unavailable');
      expect(minimal.code, isNull);
      expect(minimal.cause, isNull);
      final cause = StateError('Synthetic failure');
      final detailed = AppFailure(
        message: 'Failed',
        code: 'FAILED',
        cause: cause,
      );
      expect(detailed.code, 'FAILED');
      expect(detailed.cause, same(cause));
    },
  );
}
