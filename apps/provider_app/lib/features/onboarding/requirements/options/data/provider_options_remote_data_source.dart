import 'package:bthere_network/bthere_network.dart';

import 'provider_options_response.dart';

final class ProviderOptionsRemoteDataSource {
  const ProviderOptionsRemoteDataSource(this.client);
  final ApiClient client;
  Future<Object?> loadSelections(int id) async => (await client.get<Object?>(
    '/providers/me/services/$id/options',
    requiresAuth: true,
  )).data;
  Future<void> saveSelections(int id, List<int> optionIds) async {
    Future<bool> matches() async {
      final saved = parseProviderOptions(await loadSelections(id));
      final ids = saved.map((option) => option.optionId).toSet();
      return ids.length == optionIds.length && ids.containsAll(optionIds);
    }

    // Avoid replaying a replacement that can reset existing review metadata.
    if (await matches()) return;
    try {
      await client.put<Object?>(
        '/providers/me/services/$id/options',
        requiresAuth: true,
        data: {'optionIds': List<int>.of(optionIds)},
      );
    } on NetworkException catch (error) {
      final uncertain =
          error.statusCode == 409 ||
          error.kind == NetworkExceptionKind.timeout ||
          error.kind == NetworkExceptionKind.connection ||
          (error.statusCode != null && error.statusCode! >= 500);
      if (uncertain) {
        try {
          if (await matches()) return;
        } catch (_) {
          // A failed read cannot turn the original write failure into success.
        }
      }
      if (error.statusCode == 409) {
        throw const NetworkException(
          kind: NetworkExceptionKind.badResponse,
          statusCode: 409,
          backendCode: 'OPTIONS_CONFLICT',
          message: 'These sub-services could not be updated. Reload the service and open any existing registration to manage it.',
        );
      }
      rethrow;
    }
  }
}
