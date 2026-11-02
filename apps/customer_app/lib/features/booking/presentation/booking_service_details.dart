import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_dynamic_field.dart';
import 'booking_ui_format.dart';
import 'booking_validation_group.dart';

class ServiceDetailCard extends StatelessWidget {
  const ServiceDetailCard({
    super.key,
    required this.child,
    this.label,
    this.counter,
    this.icon = Icons.description_outlined,
    this.iconUrl,
    this.onEdit,
    this.tinted = false,
    this.showIcon = true,
  });
  final Widget child;
  final String? label, iconUrl, counter;
  final IconData icon;
  final VoidCallback? onEdit;
  final bool tinted, showIcon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: tinted ? CustomerColors.selection : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CustomerColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIcon) ...[
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: CustomerColors.selection,
              borderRadius: BorderRadius.circular(12),
            ),
            child: iconUrl == null
                ? Icon(icon, color: catalogTeal, size: 24)
                : CatalogIcon(
                    appearance: ServiceAppearance(catalogTeal, icon),
                    url: iconUrl,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label!,
                          style: const TextStyle(
                            color: catalogMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (counter != null)
                        Text(
                          counter!,
                          style: const TextStyle(
                            color: catalogMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              child,
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            tooltip: 'Change service location',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onEdit,
            icon: const Icon(Icons.chevron_right, color: catalogMuted),
          ),
      ],
    ),
  );
}

class BookingServiceFields extends StatelessWidget {
  const BookingServiceFields({super.key, required this.controller});
  final CustomerBookingController controller;
  bool _short(BookingField f) =>
      {'TEXT', 'NUMBER', 'DATE', 'TIME'}.contains(f.type) &&
      f.label.length <= 24 &&
      f.description == null;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final c = controller;
      final fields = c.context!.fields
          .where((f) => f.applies(c.answers))
          .toList();
      Widget card(BookingField field) => BookingValidationGroup(
        key: ValueKey('service-field-validation-${field.id}'),
        error: c.fieldErrors['service-field-${field.id}'],
        child: ServiceDetailCard(
          key: ValueKey('service-detail-card-${field.id}'),
          iconUrl: field.iconUrl,
          showIcon: field.iconUrl != null,
          icon: switch (field.type) {
            'PHONE' => Icons.phone_outlined,
            'EMAIL' => Icons.mail_outline,
            'DATE' || 'TIME' => Icons.schedule_outlined,
            'NUMBER' => Icons.numbers,
            _ => Icons.description_outlined,
          },
          child: BookingDynamicField(
            key: ValueKey('booking-field-${field.id}'),
            compact: true,
            showDescription:
                !RegExp(
                  r'patient|pation',
                  caseSensitive: false,
                ).hasMatch('${field.code} ${field.label}') ||
                !'${field.code} ${field.label}'.toLowerCase().contains('name'),
            field: field,
            value: c.answers[field.code],
            controller: c,
            enabled: !c.busy,
            onChanged: (value) => c.answer(field, value),
          ),
        ),
      );
      final children = <Widget>[];
      final pairs =
          bounds.maxWidth >= 300 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18;
      for (var i = 0; i < fields.length; i++) {
        if (pairs &&
            i + 1 < fields.length &&
            _short(fields[i]) &&
            _short(fields[i + 1])) {
          children.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: card(fields[i])),
                const SizedBox(width: 8),
                Expanded(child: card(fields[++i])),
              ],
            ),
          );
        } else {
          children.add(card(fields[i]));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    },
  );
}

class BookingServiceSchedule extends StatelessWidget {
  const BookingServiceSchedule({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final CustomerBookingController controller;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final start = DateTime.tryParse(c.start), end = DateTime.tryParse(c.end);
    final localizations = MaterialLocalizations.of(context);
    final displayStart = start == null
        ? 'Not selected'
        : '${localizations.formatShortMonthDay(start)}, ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    DateTime wall(DateTime date) =>
        DateTime.utc(date.year, date.month, date.day, date.hour, date.minute);
    final minutes = start == null || end == null
        ? null
        : wall(end).difference(wall(start)).inMinutes;
    final duration = minutes == null
        ? 'Not selected'
        : '${minutes ~/ 60} ${minutes ~/ 60 == 1 ? 'hour' : 'hours'}${minutes % 60 == 0 ? '' : ' ${minutes % 60}m'}';
    final cards = [
      ServiceDetailCard(
        label: c.context!.route ? 'Pickup time' : 'Scheduled for',
        icon: Icons.schedule,
        tinted: true,
        child: InkWell(
          onTap: onEdit,
          child: Semantics(
            label: bookingDisplayTime(context, c.start),
            excludeSemantics: true,
            child: Text(
              displayStart,
              style: const TextStyle(
                color: catalogInk,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      if (!c.context!.route)
        ServiceDetailCard(
          label: 'Duration',
          icon: Icons.timelapse,
          tinted: true,
          child: Text(
            duration,
            style: const TextStyle(
              color: catalogInk,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
    ];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, bounds) =>
              bounds.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 18 &&
                  cards.length == 2
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cards,
                ),
        ),
      ],
    );
  }
}
