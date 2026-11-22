import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_history.dart';

class AssignedProviderDetailsSheet extends ConsumerWidget {
  const AssignedProviderDetailsSheet({
    super.key,
    required this.provider,
    required this.owner,
    required this.jobId,
    required this.status,
    required this.onCall,
  });
  final Map<String, dynamic> provider;
  final int owner, jobId;
  final String status;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(customerAuthControllerProvider);
    final authorized =
        auth.user?.id == owner && auth.stage == CustomerAuthStage.authenticated;
    final rows = authorized
        ? ref.watch(customerBookingHistoryProvider(owner)).asData?.value
        : null;
    final current = rows?.where((r) => r['jobId'] == jobId).firstOrNull;
    final contact = provider['contact'] as Map;
    final phone = contact['phoneNumber'] ?? provider['phoneNumber'];
    final canCall =
        authorized &&
        {'CONFIRMED', 'IN_PROGRESS'}.contains(current?['status'] ?? status) &&
        contact['callAllowed'] == true &&
        phone is String &&
        phone.trim().isNotEmpty;
    final photo = provider['profilePhoto'];
    final uri = photo is String ? Uri.tryParse(photo) : null;
    final rating = provider['averageRating'];
    return SingleChildScrollView(
      key: const ValueKey('assigned-provider-details-sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Provider Details', style: CustomerTypography.screen),
          const SizedBox(height: 18),
          if (authorized)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CustomerColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: CustomerColors.selection,
                        child:
                            uri != null &&
                                {'https', 'http'}.contains(uri.scheme)
                            ? ClipOval(
                                child: Image.network(
                                  photo as String,
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person_outline,
                                    color: CustomerColors.action,
                                    size: 32,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person_outline,
                                color: CustomerColors.action,
                                size: 32,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider['displayName'] as String,
                              style: CustomerTypography.section,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: CustomerColors.selection,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                provider['role'] == 'TEAM_MEMBER'
                                    ? 'Team member'
                                    : 'Provider',
                                style: CustomerTypography.compactStrong
                                    .copyWith(color: CustomerColors.action),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canCall)
                        IconButton.filledTonal(
                          tooltip: 'Call provider',
                          style: IconButton.styleFrom(
                            backgroundColor: CustomerColors.selection,
                            foregroundColor: CustomerColors.action,
                          ),
                          onPressed: onCall,
                          icon: const Icon(Icons.call_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFBC00),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rating is num
                                ? '${rating.toStringAsFixed(1)} (${provider['totalRatings'] ?? 0} reviews)'
                                : 'No rating available',
                            style: CustomerTypography.card,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canCall) ...[
                    const SizedBox(height: 12),
                    Text(phone, style: CustomerTypography.body),
                  ],
                  if (provider['ratedByYou'] == true) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Reviewed by you',
                      style: CustomerTypography.compact,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: CustomerColors.selection,
              foregroundColor: CustomerColors.action,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
