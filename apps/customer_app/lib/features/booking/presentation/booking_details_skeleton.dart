import 'package:flutter/material.dart';

class BookingDetailsPageSkeleton extends StatelessWidget {
  const BookingDetailsPageSkeleton({super.key});

  Widget _block(double height, {double? width}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE3F0EE),
      borderRadius: BorderRadius.circular(12),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading booking details',
    liveRegion: true,
    child: ExcludeSemantics(
      child: SingleChildScrollView(
        key: const ValueKey('booking-details-page-skeleton'),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _block(20),
                                const SizedBox(height: 12),
                                _block(12, width: 90),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _block(28, width: 110),
                      ),
                      const SizedBox(height: 16),
                      _block(174),
                      const SizedBox(height: 12),
                      const BookingDetailsSkeleton(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _block(100)),
                          const SizedBox(width: 10),
                          Expanded(child: _block(100)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _block(60),
                      const SizedBox(height: 12),
                      _block(72),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Static placeholders avoid extra animation work while booking reads complete.
class BookingDetailsSkeleton extends StatelessWidget {
  const BookingDetailsSkeleton({super.key, this.review = false});
  final bool review;

  Widget _line(double width, double height) => FractionallySizedBox(
    widthFactor: width,
    alignment: Alignment.centerLeft,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDDEDEB),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: review ? 'Loading review options' : 'Loading provider details',
    child: ExcludeSemantics(
      child: Container(
        margin: review ? const EdgeInsets.only(bottom: 10) : EdgeInsets.zero,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: review ? const Color(0xFFEEF9F7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            if (!review) ...[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE7F3F1),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(review ? .65 : .35, 10),
                  const SizedBox(height: 8),
                  _line(.8, review ? 12 : 14),
                  if (!review) ...[const SizedBox(height: 8), _line(.6, 10)],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3F1),
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
