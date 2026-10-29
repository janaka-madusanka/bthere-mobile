import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_network/bthere_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_providers.dart';
import '../../requirements/data/provider_schema_response.dart' as json;

final providerProfileDetailsProvider =
    FutureProvider.autoDispose<Result<Map<String, dynamic>>>((ref) async {
      try {
        final raw =
            (await ref
                    .watch(apiClientProvider)
                    .get<Object?>('/providers/me/profile', requiresAuth: true))
                .data;
        final value = json.object(raw);
        json.integer(value['serviceProviderId'], positive: true);
        json.integer(value['userId'], positive: true);
        json.integer(value['marketId'], positive: true);
        for (final key in [
          'firstName',
          'lastName',
          'dateOfBirth',
          'gender',
          'availabilityStatus',
          'verificationStatus',
        ]) {
          json.string(value[key]);
        }
        return Success(Map<String, dynamic>.from(value));
      } on NetworkException catch (e) {
        return Failure(e.toAppFailure());
      } catch (_) {
        return const Failure(
          AppFailure(
            message: 'Unable to load your provider profile. Please retry.',
          ),
        );
      }
    }, dependencies: [apiClientProvider]);
