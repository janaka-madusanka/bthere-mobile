// Debug-only emulator harness. Synthetic repositories never touch live accounts.
import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider_app/app/app.dart';
import 'package:provider_app/app/config/app_config.dart';
import 'package:provider_app/app/providers/app_providers.dart';
import 'package:provider_app/features/onboarding/data/provider_completion_response.dart';
import 'package:provider_app/features/onboarding/services/data/provider_service_response.dart';

import '../test/support/fake_completion_repository.dart';
import '../test/support/fake_configured_service.dart';
import '../test/support/fake_service_repository.dart';
import '../test/support/fake_session_storage.dart';

void main() {
  if (!kDebugMode) throw StateError('Preview requires a debug build.');
  final services = configuredServiceRepository()
    ..catalog = Success(
      parseActiveProviderServices([
        serviceJson(id: 3, name: 'Preview care service')
          ..['description'] =
              'Professional care services at home and in hospital.',
        serviceJson(id: 9, name: 'Preview guide service')
          ..['description'] =
              'Support clients with local travel and activities.',
        for (var id = 20; id < 28; id++)
          serviceJson(id: id, name: 'Preview service $id'),
      ]),
    );
  final completion = FakeCompletionRepository()
    ..result = Success(parseProviderCompletion(completionJson()));
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(apiBaseUrl: 'https://example.invalid/api/v1'),
        ),
        clockProvider.overrideWithValue(() => testNow),
        sessionStorageProvider.overrideWithValue(
          FakeSessionStorage()..session = testSession(),
        ),
        providerServiceRepositoryProvider.overrideWithValue(services),
        providerCompletionRepositoryProvider.overrideWithValue(completion),
        providerSchemaRepositoryProvider.overrideWithValue(
          configuredSchemaRepository(),
        ),
        providerOptionsRepositoryProvider.overrideWithValue(
          configuredOptionsRepository(),
        ),
        apiClientProvider.overrideWith(
          (_) => throw StateError('No live transport in preview'),
        ),
        googleIdentityProvider.overrideWith(
          (_) => throw StateError('Google stays dormant'),
        ),
      ],
      child: const BThereProviderApp(),
    ),
  );
}
