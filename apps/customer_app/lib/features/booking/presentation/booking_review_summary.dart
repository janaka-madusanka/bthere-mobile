import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';
import '../../discovery/presentation/customer_discovery_style.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import 'booking_service_details.dart';
import 'booking_ui_format.dart';

class BookingReviewSummary extends StatelessWidget {
  const BookingReviewSummary({
    super.key,
    required this.controller,
    this.onEdit,
  });
  final CustomerBookingController controller;
  final VoidCallback? onEdit;

  Widget _detail(
    IconData icon,
    String label,
    String value, {
    String? iconUrl,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CustomerColors.selection,
            borderRadius: BorderRadius.circular(12),
          ),
          child: iconUrl == null
              ? Icon(icon, size: 21, color: catalogTeal)
              : CatalogIcon(
                  appearance: ServiceAppearance(catalogTeal, icon),
                  url: iconUrl,
                  size: 21,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: catalogInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 12, color: catalogMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ctx = c.context!;
    final icon = ctx.option['icon'];
    final iconUrl = icon is Map
        ? safeImageUrl(icon['url'])
        : safeImageUrl(ctx.option['iconUrl']);
    final fields = ctx.fields
        .where((f) => f.applies(c.answers) && c.answers[f.code] != null)
        .toList();
    final nameField = fields.where((f) {
      final key = '${f.code} ${f.label}'.toLowerCase();
      return f.code.toUpperCase() == 'NAME' ||
          (key.contains('name') &&
              RegExp(r'person|patient|pation|customer|recipient|client|full')
                  .hasMatch(key));
    }).firstOrNull;
    final contactField = fields
        .where(
          (f) =>
              f != nameField &&
              (f.type == 'PHONE' ||
                  RegExp(
                    r'contact|phone|mobile',
                    caseSensitive: false,
                  ).hasMatch('${f.code} ${f.label}')),
        )
        .firstOrNull;
    final otherFields = fields
        .where((f) => f != nameField && f != contactField)
        .toList();
    Widget answer(BookingField f) {
      final value = c.answers[f.code];
      final display = f.upload
          ? 'Uploaded private files'
          : value is bool
          ? (value ? 'Yes' : 'No')
          : value is List
          ? value.join(', ')
          : '$value';
      return _detail(
        f == nameField
            ? Icons.person_outline
            : f == contactField
            ? Icons.phone_outlined
            : switch (f.type) {
                'PHONE' => Icons.phone_outlined,
                'EMAIL' => Icons.email_outlined,
                _ => Icons.description_outlined,
              },
        f.label,
        display,
        iconUrl: f.iconUrl,
      );
    }

    final location = _detail(
      Icons.location_on,
      ctx.route ? 'Pickup location' : 'Location',
      c.mode == 'ONLINE'
          ? 'Online'
          : c.mode == 'CUSTOMER_TO_PROVIDER'
          ? 'Selected provider location'
          : bookingShortAddress(c.address),
    );

    return Container(
      key: const ValueKey('booking-review-summary'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDEFF0)),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF2FBFB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: CustomerColors.selection,
                child: CatalogIcon(
                  appearance: const ServiceAppearance(
                    catalogTeal,
                    Icons.room_service_outlined,
                  ),
                  url: iconUrl,
                  size: 27,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ctx.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: catalogInk,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (nameField != null) answer(nameField),
          if (contactField == null)
            location
          else
            LayoutBuilder(
              builder: (context, bounds) {
                if (bounds.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(12) > 18) {
                  return Column(children: [location, answer(contactField)]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: location),
                    const SizedBox(width: 10),
                    Expanded(child: answer(contactField)),
                  ],
                );
              },
            ),
          if (ctx.route)
            _detail(
              Icons.flag_outlined,
              'Destination',
              bookingShortAddress(c.destinationAddress),
            ),
          for (final provider in c.selected.values)
            _detail(Icons.person_outline, 'Provider', provider.name),
          LayoutBuilder(
            builder: (context, bounds) {
              final children = <Widget>[];
              final paired =
                  bounds.maxWidth >= 290 &&
                  MediaQuery.textScalerOf(context).scale(12) <= 16;
              bool short(BookingField f) =>
                  {'TEXT', 'NUMBER', 'DATE', 'TIME'}.contains(f.type) &&
                  '${c.answers[f.code]}'.length < 35 &&
                  f.label.length < 25;
              for (var i = 0; i < otherFields.length; i++) {
                if (paired &&
                    i + 1 < otherFields.length &&
                    short(otherFields[i]) &&
                    short(otherFields[i + 1])) {
                  children.add(
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: answer(otherFields[i])),
                        const SizedBox(width: 10),
                        Expanded(child: answer(otherFields[++i])),
                      ],
                    ),
                  );
                } else {
                  children.add(answer(otherFields[i]));
                }
              }
              return Column(children: children);
            },
          ),
          if (c.note.isNotEmpty) _detail(Icons.notes_outlined, 'Notes', c.note),
          const SizedBox(height: 6),
          BookingServiceSchedule(controller: c, onEdit: onEdit),
        ],
      ),
    );
  }
}
