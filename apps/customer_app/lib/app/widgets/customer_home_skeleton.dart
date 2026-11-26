import 'package:flutter/material.dart';

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder(this.height, {this.width});
  final double height;
  final double? width;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: const Color(0xFFE1EFEE),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

/// Static placeholders match Home without adding animation during network work.
class CustomerHomeSkeleton extends StatelessWidget {
  const CustomerHomeSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading home',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        key: const ValueKey('customer-home-loading-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: _HomePlaceholder(12, width: 100),
          ),
          const SizedBox(height: 12),
          const AspectRatio(
            aspectRatio: 1.8,
            child: _HomePlaceholder(double.infinity),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: _HomePlaceholder(18, width: 140),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < 4; i++)
                  SizedBox(
                    width: (bounds.maxWidth - 10) / 2,
                    child: const _HomePlaceholder(74),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: _HomePlaceholder(18, width: 130),
          ),
          const SizedBox(height: 12),
          const CustomerRecentBookingsSkeleton(),
        ],
      ),
    ),
  );
}

class CustomerRecentBookingsSkeleton extends StatelessWidget {
  const CustomerRecentBookingsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading recent bookings',
    liveRegion: true,
    child: ExcludeSemantics(
      child: Column(
        key: const ValueKey('customer-recent-loading-skeleton'),
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  _HomePlaceholder(40, width: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HomePlaceholder(13),
                        SizedBox(height: 8),
                        _HomePlaceholder(10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
