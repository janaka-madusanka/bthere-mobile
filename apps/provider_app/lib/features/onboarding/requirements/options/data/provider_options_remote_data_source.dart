import 'package:bthere_network/bthere_network.dart';

final class ProviderOptionsRemoteDataSource {
  const ProviderOptionsRemoteDataSource(this.client);
  final ApiClient client;
  Future<Object?> loadSelections(int id) async => (await client.get<Object?>(
    '/providers/me/services/$id/options',
    requiresAuth: true,
  )).data;
  Future<void> saveSelections(int id, List<int> optionIds) async {
    await client.put<Object?>(
      '/providers/me/services/$id/options',
      requiresAuth: true,
      data: {'optionIds': List<int>.of(optionIds)},
    );
  }
}
