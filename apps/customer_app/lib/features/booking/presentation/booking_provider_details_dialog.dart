import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../domain/booking_models.dart';

/// Optional public profile content, mapped only from a confirmed API contract.
/// Search candidates alone do not imply skills, verification or work reviews.
class ProviderProfileDetails {
  const ProviderProfileDetails({
    this.about,
    this.experienceYears,
    this.location,
    this.skills = const [],
    this.reviews = const [],
  });
  final String? about, location;
  final num? experienceYears;
  final List<String> skills;
  final List<ProviderWorkReview> reviews;
}

class ProviderWorkReview {
  const ProviderWorkReview({
    required this.name,
    required this.rating,
    required this.text,
    required this.date,
  });
  final String name, text, date;
  final num rating;
}

Future<void> showBookingProviderDetails(
  BuildContext context,
  ProviderCandidate candidate, {
  ProviderProfileDetails? details,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      BookingProviderDetailsDialog(candidate: candidate, details: details),
);

class BookingProviderDetailsDialog extends StatelessWidget {
  const BookingProviderDetailsDialog({
    super.key,
    required this.candidate,
    this.details,
  });
  final ProviderCandidate candidate;
  final ProviderProfileDetails? details;
  static const _ink = Color(0xFF0C1248);

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(height: 1, color: Color(0xFFE9EDF3)),
      ),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );

  Widget _chips(List<String> values) => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final value in values)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: CustomerColors.selection,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CustomerColors.action,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final rating = candidate.data['averageRating'];
    final count = candidate.data['totalRatings'];
    final languages = (candidate.data['languages'] as List? ?? const [])
        .whereType<String>()
        .map(
          (value) => value.isEmpty
              ? value
              : '${value[0]}${value.substring(1).toLowerCase()}',
        )
        .toList();
    final distance = candidate.data['distanceKm'];
    return Dialog(
      key: const ValueKey('booking-provider-details-dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  tooltip: 'Close provider details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 21),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F2F7),
                    foregroundColor: _ink,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final compact =
                              bounds.maxWidth < 300 ||
                              MediaQuery.textScalerOf(context).scale(14) > 20;
                          final profile = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.name,
                                style: const TextStyle(
                                  fontSize: 21,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              if (rating is num) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: Color(0xFFF5B83D),
                                      size: 21,
                                    ),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                    if (count is int)
                                      Text(
                                        '($count ratings)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: CustomerColors.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (details?.experienceYears
                                  case final years?) ...[
                                const SizedBox(height: 10),
                                _ProfileLine(
                                  icon: Icons.work_outline_rounded,
                                  text: '$years years of experience',
                                ),
                              ],
                              if (details?.location case final location?) ...[
                                const SizedBox(height: 6),
                                _ProfileLine(
                                  icon: Icons.place_outlined,
                                  text: location,
                                ),
                              ] else if (distance is num) ...[
                                const SizedBox(height: 8),
                                _ProfileLine(
                                  icon: Icons.place_outlined,
                                  text:
                                      '${distance.toStringAsFixed(1)} km from your search location',
                                ),
                              ],
                            ],
                          );
                          final avatar = ClipOval(
                            child: SizedBox(
                              width: compact ? 78 : 96,
                              height: compact ? 78 : 96,
                              child: candidate.photo == null
                                  ? _fallback
                                  : Image.network(
                                      candidate.photo!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => _fallback,
                                    ),
                            ),
                          );
                          return compact
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    avatar,
                                    const SizedBox(height: 12),
                                    profile,
                                  ],
                                )
                              : Row(
                                  children: [
                                    avatar,
                                    const SizedBox(width: 18),
                                    Expanded(child: profile),
                                  ],
                                );
                        },
                      ),
                      if (details?.about case final about?)
                        _section(
                          'About Me',
                          Text(
                            about,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: CustomerColors.secondaryText,
                            ),
                          ),
                        ),
                      if (details?.skills.isNotEmpty == true)
                        _section('Skills', _chips(details!.skills)),
                      if (languages.isNotEmpty)
                        _section('Languages', _chips(languages)),
                      if (details?.reviews.isNotEmpty == true)
                        _section(
                          'Previous Work',
                          Column(
                            children: [
                              for (final review in details!.reviews)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 9),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE5E9F2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 5,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            review.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _ink,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFF5B83D),
                                            size: 16,
                                          ),
                                          Text(
                                            review.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _ink,
                                            ),
                                          ),
                                          Text(
                                            review.date,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color:
                                                  CustomerColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        review.text,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.45,
                                          color: CustomerColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('booking-provider-details-close'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _fallback => const ColoredBox(
    color: CustomerColors.selection,
    child: Icon(
      Icons.person_outline_rounded,
      color: CustomerColors.action,
      size: 40,
    ),
  );
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: CustomerColors.secondaryText),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            height: 1.35,
            color: CustomerColors.secondaryText,
          ),
        ),
      ),
    ],
  );
}
