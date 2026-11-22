import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../domain/booking_tracking.dart';
import '../domain/booking_models.dart';
import 'booking_provider_details_dialog.dart';
import 'customer_provider_reviews.dart';

class TrackingProviderDetails extends StatelessWidget {
  const TrackingProviderDetails({
    super.key,
    required this.tracking,
    required this.now,
    this.readFailed = false,
  });
  final BookingTrackingStatus tracking;
  final DateTime now;
  final bool readFailed;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final provider in tracking.providers)
        Container(
          key: ValueKey('tracking-profile-${provider.id}'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: CustomerColors.selection,
                    foregroundImage: provider.photo == null
                        ? null
                        : NetworkImage(provider.photo!),
                    child: const Icon(
                      Icons.person_outline,
                      color: CustomerColors.action,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(provider.name, style: CustomerTypography.card),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                provider.point == null
                    ? 'Waiting for shared location…'
                    : readFailed || provider.stale(now, tracking.staleSeconds)
                    ? 'Updating location…'
                    : '${provider.data['status'] ?? tracking.status}'
                          .replaceAll('_', ' ')
                          .toLowerCase(),
                style: CustomerTypography.compact,
              ),
              if (!readFailed &&
                  provider.point != null &&
                  !provider.stale(now, tracking.staleSeconds)) ...[
                if (provider.data['etaMinutes'] case final num eta)
                  Text(
                    'Approx. ${eta.ceil()} min to ${tracking.payload['target'] is Map && tracking.payload['target']['label'] == 'DESTINATION' ? 'destination' : 'you'}',
                    style: CustomerTypography.card,
                  ),
                if (provider.data['distanceKm'] case final num km)
                  Text(
                    '${km.toStringAsFixed(1)} km · Estimated from direct distance',
                    style: CustomerTypography.micro,
                  ),
              ],
              for (final raw
                  in tracking.payload['providerDisplayFields'] as List? ?? [])
                if (raw is Map &&
                    raw['fieldId'] is int &&
                    raw['label'] is String &&
                    provider.data['providerAttributes'] is Map &&
                    provider.data['providerAttributes']['${raw['fieldId']}'] !=
                        null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${raw['label']}: ${_answer(raw, provider.data['providerAttributes']['${raw['fieldId']}'])}',
                      style: CustomerTypography.compact,
                    ),
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => showBookingProviderDetails(
                    context,
                    ProviderCandidate({
                      ...provider.data,
                      'languages': <String>[],
                    }),
                    feedback: CustomerProviderReviews(providerId: provider.id),
                  ),
                  child: const Text('Provider details & reviews'),
                ),
              ),
            ],
          ),
        ),
    ],
  );
  String _answer(Map field, Object? value) {
    if (value is List) return value.map((v) => _answer(field, v)).join(', ');
    for (final choice in field['options'] as List? ?? []) {
      if (choice is Map && choice['value'] == value) {
        return '${choice['label'] ?? value}';
      }
    }
    return value is String || value is num || value is bool
        ? '$value'
        : 'Not available';
  }
}
