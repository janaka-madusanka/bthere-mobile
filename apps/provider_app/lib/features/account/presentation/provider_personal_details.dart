import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/profile/data/provider_profile_reader.dart';
import '../../onboarding/profile/presentation/provider_profile_screen.dart';

class ProviderPersonalDetails extends ConsumerWidget {
  const ProviderPersonalDetails({this.enabled = true, super.key});
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(providerProfileDetailsProvider),
        result = state.asData?.value;
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result is! Success<Map<String, dynamic>>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unable to load provider details.'),
          TextButton(
            onPressed: enabled
                ? () => ref.invalidate(providerProfileDetailsProvider)
                : null,
            child: const Text('Retry provider details'),
          ),
        ],
      );
    }
    final profile = result.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${profile['firstName']} ${profile['lastName']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text('Date of birth: ${profile['dateOfBirth']}'),
        Text('Gender: ${profile['gender']}'),
        Text('Availability: ${profile['availabilityStatus']}'),
        Text('Verification: ${profile['verificationStatus']}'),
        if (profile['bio'] != null) Text(profile['bio'] as String),
        TextButton(
          onPressed: !enabled
              ? null
              : () async {
                  final container = ProviderScope.containerOf(context);
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => UncontrolledProviderScope(
                        container: container,
                        child: ProviderProfileScreen(
                          initialProfile: profile,
                          onBack: () => Navigator.pop(context),
                          onSaved: () {
                            ref.invalidate(providerProfileDetailsProvider);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  );
                },
          child: const Text('Edit provider details'),
        ),
      ],
    );
  }
}
