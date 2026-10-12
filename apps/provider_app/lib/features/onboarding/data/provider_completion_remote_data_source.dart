import 'package:bthere_network/bthere_network.dart';

final class ProviderCompletionRemoteDataSource {
  const ProviderCompletionRemoteDataSource(this._client);
  final ApiClient _client;
  Future<Object?> loadCompletion() async => (await _client.get<Object?>(
    '/providers/me/completion',
    requiresAuth: true,
  )).data;
}
