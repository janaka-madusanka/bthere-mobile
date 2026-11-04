import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_location_picker.dart';
import 'booking_service_dropdown.dart';
import 'booking_provider_details_dialog.dart';

class BookingProviderResultsCanvas extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = controller;
    final icon = c.context!.option['icon'];
    return BookingProviderResultsView(
      candidates: c.candidates,
      selected: c.selected,
      point: c.point,
      radius: c.radius,
      serviceName: c.context!.name,
      iconUrl: icon is Map ? safeImageUrl(icon['url']) : null,
      online: c.mode == 'ONLINE',
      requiredCount: c.context!.providerCount,
      busy: c.busy,
      hasNext: c.hasNext,
      error: c.error,
      onBack: onBack,
      onSelect: c.select,
      onProviderDetails: (candidate) =>
          showBookingProviderDetails(context, candidate),
      onContinue: c.continueWithProviders,
      onLoadMore: () => c.search(more: true),
      onChangeFilters: c.details,
      wrapServiceHeader: (child) => BookingServiceDropdown(
        controller: c,
        onChanged: onOptionChanged,
        child: child,
      ),
    );
  }
}

/// Existing provider results presentation, shared with the offline gallery.
class BookingProviderResultsView extends StatefulWidget {
  const BookingProviderResultsView({
    super.key,
    required this.candidates,
    required this.selected,
    required this.point,
    required this.radius,
    required this.serviceName,
    required this.requiredCount,
    required this.onBack,
    required this.onSelect,
    required this.onContinue,
    required this.onLoadMore,
    required this.onChangeFilters,
    required this.wrapServiceHeader,
    this.online = false,
    this.busy = false,
    this.hasNext = false,
    this.iconUrl,
    this.error,
    this.mapBuilder,
    this.onProviderDetails,
  });
  final List<ProviderCandidate> candidates;
  final Map<int, ProviderCandidate> selected;
  final GeoPoint? point;
  final double radius;
  final String serviceName;
  final String? iconUrl, error;
  final int requiredCount;
  final bool online, busy, hasNext;
  final VoidCallback onBack, onContinue, onLoadMore, onChangeFilters;
  final ValueChanged<ProviderCandidate> onSelect;
  final ValueChanged<ProviderCandidate>? onProviderDetails;
  final Widget Function(Widget child) wrapServiceHeader;
  final Widget Function(double height)? mapBuilder;

  @override
  State<BookingProviderResultsView> createState() =>
      _BookingProviderResultsViewState();
}

class _BookingProviderResultsViewState
    extends State<BookingProviderResultsView> {
  final _sheet = DraggableScrollableController();
  double get _initial => MediaQuery.textScalerOf(context).scale(14) > 21
      ? .72
      : widget.candidates.length >= 5
      ? .62
      : widget.candidates.length > 2
      ? .58
      : .44;
  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.online;
    final count = widget.candidates
        .map((candidate) => candidate.id)
        .toSet()
        .length;
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
                builder: (_, _) =>
                    widget.mapBuilder?.call(
                      bounds.maxHeight *
                          (1 - (_sheet.isAttached ? _sheet.size : _initial)),
                    ) ??
                    BookingLocationPicker(
                      point: widget.point,
                      candidates: widget.candidates,
                      radiusKm: widget.radius,
                      enabled: false,
                      showRecenter: true,
                      mapOnly: true,
                      onChanged: (_) {},
                      onProviderSelected: widget.busy ? null : widget.onSelect,
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
                    onPressed: widget.busy ? null : widget.onBack,
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
                      child: widget.wrapServiceHeader(
                        Padding(
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
                                url: widget.iconUrl,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.serviceName,
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
                                            color: Color(0xFF0C1248),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$count${widget.hasNext ? '+' : ''} ${count == 1 && !widget.hasNext ? 'provider' : 'providers'}',
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
                                    widget.requiredCount == 1
                                        ? 'Choose your provider'
                                        : 'Choose ${widget.requiredCount} providers · ${widget.selected.length} selected',
                                    style: const TextStyle(
                                      color: catalogMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (widget.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        widget.error!,
                                        style: const TextStyle(
                                          color: CustomerColors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (widget.busy)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (widget.candidates.isEmpty)
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
                              itemCount: widget.candidates.length,
                              itemBuilder: (_, index) {
                                final candidate = widget.candidates[index];
                                return BookingProviderCard(
                                  candidate: candidate,
                                  onDetails:
                                      widget.onProviderDetails == null ||
                                          widget.busy
                                      ? null
                                      : () => widget.onProviderDetails!(
                                          candidate,
                                        ),
                                  selected:
                                      widget.selected[candidate.id]?.key ==
                                      candidate.key,
                                  onTap: widget.busy
                                      ? null
                                      : () => widget.onSelect(candidate),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (widget.hasNext)
                                  TextButton(
                                    onPressed: widget.busy
                                        ? null
                                        : widget.onLoadMore,
                                    child: const Text('Load more providers'),
                                  ),
                                TextButton(
                                  onPressed: widget.busy
                                      ? null
                                      : widget.onChangeFilters,
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
                              widget.busy ||
                                  widget.selected.length != widget.requiredCount
                              ? null
                              : widget.onContinue,
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
    this.onDetails,
  });
  final ProviderCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;

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
            color: Color(0xFF0C1248),
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            Icon(
              rated ? Icons.star_rounded : Icons.star_outline_rounded,
              color: rated ? const Color(0xFFF5B42A) : catalogMuted,
              size: 16,
            ),
            Text(
              rated ? rating.toStringAsFixed(1) : 'Not yet rated',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: rated ? const Color(0xFF0C1248) : catalogMuted,
                fontWeight: rated ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (rated && ratings != null)
              Text(
                '($ratings)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9598B2)),
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
          const SizedBox(height: 5),
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
                    color: const Color(0xFFF1F0FD),
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
        minimumSize: const Size(74, 42),
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
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? catalogTeal : const Color(0xFFE7E8F2),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onDetails ?? onTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final narrow =
                      bounds.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: Container(
                          width: 54,
                          height: 54,
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
