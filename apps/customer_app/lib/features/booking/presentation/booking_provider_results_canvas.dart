import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_location_picker.dart';
import 'booking_service_dropdown.dart';

class BookingProviderResultsCanvas extends StatefulWidget {
  const BookingProviderResultsCanvas({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onOptionChanged,
  });
  final CustomerBookingController controller;
  final VoidCallback onBack;
  final ValueChanged<CustomerServiceOption> onOptionChanged;
  @override
  State<BookingProviderResultsCanvas> createState() =>
      _BookingProviderResultsCanvasState();
}

class _BookingProviderResultsCanvasState
    extends State<BookingProviderResultsCanvas> {
  final _sheet = DraggableScrollableController();
  double get _initial => MediaQuery.textScalerOf(context).scale(14) > 21
      ? .72
      : widget.controller.candidates.length >= 5
      ? .62
      : widget.controller.candidates.length > 2
      ? .58
      : .44;
  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final online = c.mode == 'ONLINE';
    final count = c.candidates.map((candidate) => candidate.id).toSet().length;
    final icon = c.context!.option['icon'];
    final iconUrl = icon is Map ? safeImageUrl(icon['url']) : null;
    return LayoutBuilder(
      builder: (context, bounds) => Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFE9F6F4))),
          if (!online)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _sheet,
                builder: (_, _) => BookingLocationPicker(
                  point: c.point,
                  candidates: c.candidates,
                  radiusKm: c.radius,
                  enabled: false,
                  showRecenter: true,
                  mapOnly: true,
                  onChanged: (_) {},
                  onProviderSelected: c.busy ? null : c.select,
                  preferProviderPhotos: true,
                  height:
                      bounds.maxHeight *
                      (1 - (_sheet.isAttached ? _sheet.size : _initial)),
                ),
              ),
            ),
          if (online)
            const Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Icon(
                Icons.videocam_outlined,
                color: catalogTeal,
                size: 90,
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Material(
                  color: Colors.white,
                  elevation: 3,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: c.busy ? null : widget.onBack,
                    icon: const Icon(Icons.arrow_back, color: catalogInk),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(24),
                      child: BookingServiceDropdown(
                        controller: c,
                        onChanged: widget.onOptionChanged,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CatalogIcon(
                                appearance: const ServiceAppearance(
                                  catalogTeal,
                                  Icons.medical_services_outlined,
                                ),
                                url: iconUrl,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  c.context!.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: catalogInk,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: catalogInk,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            key: const ValueKey('booking-providers-sheet'),
            controller: _sheet,
            initialChildSize: _initial,
            minChildSize: .26,
            maxChildSize: .88,
            snap: true,
            snapSizes: [.26, _initial, .88],
            builder: (context, scroll) => Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: scroll,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                10,
                                18,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 38,
                                      height: 4,
                                      margin: const EdgeInsets.only(bottom: 18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFBCC4CA),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          online
                                              ? 'Available providers'
                                              : 'Available providers nearby',
                                          style: const TextStyle(
                                            color: catalogInk,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$count${c.hasNext ? '+' : ''} ${count == 1 && !c.hasNext ? 'provider' : 'providers'}',
                                        style: const TextStyle(
                                          color: catalogMuted,
                                          fontSize: 11,
                                          height: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    c.context!.providerCount == 1
                                        ? 'Choose your provider'
                                        : 'Choose ${c.context!.providerCount} providers · ${c.selected.length} selected',
                                    style: const TextStyle(
                                      color: catalogMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (c.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        c.error!,
                                        style: const TextStyle(
                                          color: CustomerColors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (c.busy)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (c.candidates.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        'No matching providers just yet. Try another time or search area.',
                                        style: TextStyle(color: catalogMuted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: c.candidates.length,
                              itemBuilder: (_, index) {
                                final candidate = c.candidates[index];
                                return BookingProviderCard(
                                  candidate: candidate,
                                  selected:
                                      c.selected[candidate.id]?.key ==
                                      candidate.key,
                                  onTap: c.busy
                                      ? null
                                      : () => c.select(candidate),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (c.hasNext)
                                  TextButton(
                                    onPressed: c.busy
                                        ? null
                                        : () => c.search(more: true),
                                    child: const Text('Load more providers'),
                                  ),
                                TextButton(
                                  onPressed: c.busy ? null : c.details,
                                  child: const Text(
                                    'Change time, location or details',
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    0,
                                    18,
                                    12,
                                  ),
                                  child: Text(
                                    online
                                        ? 'Availability is checked again when you book.'
                                        : 'Pins show public locations or approximate service areas. Availability is checked again when you book.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: catalogMuted,
                                      fontSize: 10,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('booking-results-continue'),
                          onPressed:
                              c.busy ||
                                  c.selected.length != c.context!.providerCount
                              ? null
                              : c.continueWithProviders,
                          style: FilledButton.styleFrom(
                            backgroundColor: catalogTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingProviderCard extends StatelessWidget {
  const BookingProviderCard({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });
  final ProviderCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rating = candidate.data['averageRating'] as num?;
    final ratings = candidate.data['totalRatings'] as int?;
    final rated = rating != null && (ratings == null || ratings > 0);
    final distance = candidate.data['distanceKm'] as num?;
    final languages = (candidate.data['languages'] as List).cast<String>();
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          candidate.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: catalogInk,
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            Icon(
              rated ? Icons.star_rounded : Icons.star_outline_rounded,
              color: rated ? const Color(0xFFF5B42A) : catalogMuted,
              size: 14,
            ),
            Text(
              rated
                  ? '${rating.toStringAsFixed(1)}${ratings == null ? '' : ' ($ratings)'}'
                  : 'Not yet rated',
              style: const TextStyle(
                fontSize: 11,
                height: 1.2,
                color: catalogMuted,
              ),
            ),
            if (distance != null)
              Text(
                '· ${distance.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: catalogMuted,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
          ],
        ),
        if (languages.isNotEmpty) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final language in languages)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    language.isEmpty
                        ? language
                        : '${language[0]}${language.substring(1).toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF69738B),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    final button = FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: selected ? CustomerColors.primary : catalogTeal,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        minimumSize: const Size(68, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Text(
        selected ? 'Selected' : 'Select',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        child: Material(
          key: ValueKey('booking-provider-${candidate.key}'),
          color: selected ? CustomerColors.selection : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: selected ? catalogTeal : const Color(0xFFE7ECF3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final narrow =
                      bounds.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipOval(
                        child: Container(
                          width: 46,
                          height: 46,
                          color: const Color(0xFFE0F2F3),
                          child: candidate.photo == null
                              ? const Icon(
                                  Icons.person,
                                  color: catalogTeal,
                                  size: 26,
                                )
                              : Image.network(
                                  candidate.photo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    color: catalogTeal,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            details,
                            if (narrow) ...[const SizedBox(height: 8), button],
                          ],
                        ),
                      ),
                      if (!narrow) ...[const SizedBox(width: 8), button],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
