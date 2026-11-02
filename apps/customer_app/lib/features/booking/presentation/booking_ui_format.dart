import 'package:flutter/material.dart';

/// Compact display only; keep the complete address in the booking draft.
String bookingShortAddress(String value) {
  final parts = <String>[];
  for (var part in value.split(RegExp(r'[,\n]'))) {
    part = part.trim().replaceFirst(
      RegExp(
        r'^[23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]{2,3}\s*',
        caseSensitive: false,
      ),
      '',
    );
    // House numbers/postcodes alone are not a useful location label.
    part = part
        .replaceFirst(
          RegExp(
            r'^(?:no\.?\s*)?\d+(?:[/-]\d+)*[a-z]?[\s.,]+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(part) ||
        RegExp(
          r'^(?=.*\d)[A-Z0-9-]{4,}$',
          caseSensitive: false,
        ).hasMatch(part) ||
        RegExp(r'^[AB]\d+$', caseSensitive: false).hasMatch(part) ||
        {
          'unnamed road',
          'unnamed street',
          'unknown',
          'unknown road',
        }.contains(part.toLowerCase())) {
      continue;
    }
    parts.add(part);
  }
  final label = parts.isEmpty ? 'Selected on map' : parts.first;
  return label.characters.length > 32
      ? '${label.characters.take(32).toString().trimRight()}…'
      : label;
}

/// Formats market-local wall time without converting it to the device timezone.
String bookingDisplayTime(BuildContext context, String? value) {
  if (value == null || value.isEmpty) return 'Not provided';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(date)}, ${date.year} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}
