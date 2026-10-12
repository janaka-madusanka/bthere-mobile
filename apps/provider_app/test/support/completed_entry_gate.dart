import 'package:bthere_common/bthere_common.dart';
import 'package:provider_app/features/onboarding/application/provider_entry_gate.dart';

/// Existing service tests exercise providers whose account prerequisites are met.
class CompletedEntryGate extends ProviderEntryGate {
  @override
  Future<Result<bool>?> build() async => const Success(false);
}
