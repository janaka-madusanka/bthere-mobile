import 'package:bthere_network/bthere_network.dart';

import '../domain/provider_service_input.dart';

final class ProviderServiceRemoteDataSource {
  const ProviderServiceRemoteDataSource(this._client);
  final ApiClient _client;
  Future<Object?> loadServices() async =>
      (await _client.get<Object?>('/provider-types', requiresAuth: true)).data;
  Future<Object?> loadAssignments() async => (await _client.get<Object?>(
    '/providers/me/service-types',
    requiresAuth: true,
  )).data;
  Future<Object?> addService(ProviderServiceInput input) async =>
      (await _client.post<Object?>(
        '/providers/me/service-types',
        requiresAuth: true,
        data: input.toJson(),
      )).data;
}
