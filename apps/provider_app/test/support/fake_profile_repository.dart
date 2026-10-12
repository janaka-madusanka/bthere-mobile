import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_input.dart';
import 'package:provider_app/features/onboarding/profile/domain/provider_profile_repository.dart';

final class FakeProfileRepository implements ProviderProfileRepository {
  int calls = 0;
  ProviderProfileInput? input;
  Result<void> result = const Success(null);
  Completer<Result<void>>? pending;
  bool throwOnUpdate = false;
  @override
  Future<Result<void>> updateProfile(ProviderProfileInput value) async {
    calls++;
    input = value;
    if (throwOnUpdate) throw StateError('private synthetic profile error');
    return pending == null ? result : pending!.future;
  }
}
