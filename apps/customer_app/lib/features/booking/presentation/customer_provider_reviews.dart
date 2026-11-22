import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_provider_reviews_controller.dart';

class CustomerProviderReviews extends ConsumerStatefulWidget {
  const CustomerProviderReviews({
    super.key,
    required this.providerId,
    this.optionId,
  });
  final int providerId;
  final int? optionId;
  @override
  ConsumerState<CustomerProviderReviews> createState() =>
      _CustomerProviderReviewsState();
}

class _CustomerProviderReviewsState
    extends ConsumerState<CustomerProviderReviews> {
  late final CustomerProviderReviewsController c;
  @override
  void initState() {
    super.initState();
    c = CustomerProviderReviewsController(
      ref.read(customerBookingRepositoryProvider),
      ref.read(customerAuthControllerProvider),
      widget.providerId,
      widget.optionId,
    );
    c.addListener(changed);
    c.loadSummary();
    c.loadReviews();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!c.alive) return const SizedBox.shrink();
    final summary = c.summaries
        .where((s) => s.optionId == c.optionId)
        .firstOrNull;
    final scopes = [for (final s in c.summaries) (s.optionId, s.name)];
    if (c.optionId != null && !scopes.any((s) => s.$1 == c.optionId)) {
      scopes.add((c.optionId, 'Selected service'));
    }
    return Material(
      color: Colors.transparent,
      child: Column(
        key: const ValueKey('provider-reviews-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 32),
          const Text('Ratings & reviews', style: CustomerTypography.section),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in scopes)
                ChoiceChip(
                  key: ValueKey('review-scope-${s.$1 ?? 'all'}'),
                  label: Text(s.$2, style: CustomerTypography.compact),
                  selected: c.optionId == s.$1,
                  onSelected: (_) => c.select(s.$1),
                ),
            ],
          ),
          if (c.summaryLoading) const LinearProgressIndicator(),
          if (c.summaryError != null) ...[
            Text(c.summaryError!, style: CustomerTypography.compact),
            TextButton(
              onPressed: c.summaryLoading ? null : c.loadSummary,
              child: const Text('Retry summary'),
            ),
          ],
          if (summary != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: CustomerColors.selection,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    summary.average != null && summary.total > 0
                        ? '${summary.average!.toStringAsFixed(1)} / 5'
                        : 'Not yet rated',
                    style: CustomerTypography.screen,
                  ),
                  Text(
                    '${summary.total} ratings · ${summary.name}',
                    style: CustomerTypography.compact,
                  ),
                  const SizedBox(height: 10),
                  for (var star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text('$star', style: CustomerTypography.compact),
                          const Icon(
                            Icons.star_rounded,
                            color: CustomerColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: summary.total == 0
                                  ? 0
                                  : (summary.distribution[star]! /
                                            summary.total)
                                        .clamp(0.0, 1.0),
                              backgroundColor: Colors.white,
                              color: CustomerColors.action,
                              semanticsLabel:
                                  '$star stars, ${summary.distribution[star]} ratings',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${summary.distribution[star]}',
                            style: CustomerTypography.compact,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          for (final review in c.reviews)
            Container(
              key: ValueKey('provider-review-${review.id}'),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                border: Border.all(color: CustomerColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(review.name, style: CustomerTypography.card),
                  Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: CustomerColors.warning,
                        size: 16,
                      ),
                      Text(
                        '${review.stars} / 5',
                        style: CustomerTypography.compactStrong,
                      ),
                      Text(review.date, style: CustomerTypography.micro),
                    ],
                  ),
                  Text(
                    review.option,
                    style: CustomerTypography.compact.copyWith(
                      color: CustomerColors.action,
                    ),
                  ),
                  if (review.comment?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(review.comment!, style: CustomerTypography.body),
                  ],
                ],
              ),
            ),
          if (c.reviewLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!c.reviewLoading && c.reviewError == null && c.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No reviews yet for this selection.',
                style: CustomerTypography.body,
              ),
            ),
          if (c.reviewError != null) ...[
            Text(c.reviewError!, style: CustomerTypography.compact),
            TextButton(
              onPressed: c.reviewLoading ? null : c.loadReviews,
              child: const Text('Retry reviews'),
            ),
          ] else if (c.hasMore)
            OutlinedButton(
              onPressed: c.reviewLoading ? null : c.loadReviews,
              child: const Text('Load more reviews'),
            ),
        ],
      ),
    );
  }
}
