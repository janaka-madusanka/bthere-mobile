import 'package:bthere_network/bthere_network.dart';
import 'package:flutter/foundation.dart';

import 'provider_profile_diagnostics.dart';

import '../domain/provider_profile_input.dart';
import 'provider_profile_request.dart';

final class ProviderProfileRemoteDataSource {
  const ProviderProfileRemoteDataSource(this._client);
  final ApiClient _client;
  Future<void> updateProfile(ProviderProfileInput input) async {
    // The success body is not documented; successful HTTP status is the acknowledgment.
    final payload = serializeProviderProfile(input);
    final response = await _client.put<Object?>(
      '/providers/me/profile',
      requiresAuth: true,
      data: payload,
      onErrorResponse: kDebugMode
          ? (response) => debugPrint(
              providerProfileDiagnostic(
                payload: payload,
                statusCode: response?.statusCode,
                errorBody: response?.data,
              ),
            )
          : null,
    );
    if (kDebugMode) {
      debugPrint(
        providerProfileDiagnostic(
          payload: payload,
          statusCode: response.statusCode,
        ),
      );
    }
  }
}
