import 'package:bthere_network/bthere_network.dart';

final class ProviderSchemaRemoteDataSource {
  const ProviderSchemaRemoteDataSource(this.client);
  final ApiClient client;
  Future<Object?> loadSchema(int id) async => (await client.get<Object?>(
    '/provider-types/$id/onboarding-schema',
    requiresAuth: true,
  )).data;
}
