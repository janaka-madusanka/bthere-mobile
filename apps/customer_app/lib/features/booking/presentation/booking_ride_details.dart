import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../application/customer_booking_controller.dart';
import 'booking_choice_tiles.dart';
import 'booking_ui_format.dart';

class BookingRideDetails extends StatelessWidget {
  const BookingRideDetails({
    super.key,
    required this.controller,
    required this.onPickup,
    required this.onDestination,
    this.showPricing = true,
    this.showTrip = true,
  });
  final CustomerBookingController controller;
  final VoidCallback onPickup, onDestination;
  final bool showPricing, showTrip;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTrip) ...[
          Column(
            key: const ValueKey('ride-trip-summary'),
            children: [
              _stop('Pickup', c.address, Icons.trip_origin, onPickup, c.busy),
              const Padding(
                padding: EdgeInsets.only(left: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.south_rounded,
                    size: 14,
                    color: CustomerColors.muted,
                  ),
                ),
              ),
              _stop(
                'Destination',
                c.destinationAddress,
                Icons.flag_rounded,
                onDestination,
                c.busy,
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (showPricing)
          for (final field in c.context!.providerFilters.where(
            (f) => c.context!.pricingFieldIds.contains(f.id),
          )) ...[
            Text(field.label, style: CustomerTypography.card),
            const SizedBox(height: 8),
            BookingChoiceTiles(
              choices: field.options,
              selected: {
                if (c.pricingSelections[field.id] != null)
                  c.pricingSelections[field.id]!,
              },
              enabled: !c.busy,
              filterStyle: true,
              onChanged: (value, selected) =>
                  c.choosePricing(field.id, selected ? value : null),
            ),
            if (c.fieldErrors['pricing-${field.id}'] case final String error)
              Text(
                error,
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.error,
                ),
              ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }

  Widget _stop(
    String label,
    String address,
    IconData icon,
    VoidCallback action,
    bool busy,
  ) {
    final pickup = label == 'Pickup';
    final accent = pickup ? CustomerColors.action : const Color(0xFFB86A20);
    return Semantics(
      label: 'Change ${label.toLowerCase()} location',
      button: true,
      child: Material(
        key: ValueKey('ride-stop-${pickup ? 'pickup' : 'destination'}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: .25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : action,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: CustomerTypography.compact.copyWith(
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          address.isEmpty
                              ? (pickup
                                    ? 'Where should we pick you up?'
                                    : 'Where are you going?')
                              : bookingShortAddress(address),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CustomerTypography.card.copyWith(
                            color: address.isEmpty
                                ? CustomerColors.secondaryText
                                : CustomerColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
