import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';

class BookingSchedulePicker extends StatelessWidget {
  const BookingSchedulePicker({super.key, required this.controller});
  final CustomerBookingController controller;

  DateTime get _now => tz.TZDateTime.from(
    controller.now(),
    MarketTime.location(controller.context!.zone),
  );
  DateTime get _suggested {
    final now = _now;
    // Work in market-local wall time; existing controller validates DST/future time.
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      ((now.minute ~/ 15) + 1) * 15,
    );
  }

  DateTime _wall(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  );
  DateTime get _start => DateTime.tryParse(controller.start) == null
      ? _suggested
      : _wall(DateTime.parse(controller.start));
  DateTime get _end {
    final parsed = DateTime.tryParse(controller.end);
    final end = parsed == null ? null : _wall(parsed);
    return end != null && end.isAfter(_start)
        ? end
        : _start.add(const Duration(hours: 6));
  }

  void _set(DateTime start, DateTime end) => controller.edit(() {
    controller.start = MarketTime.local(start);
    if (!controller.context!.route) controller.end = MarketTime.local(end);
  });
  void _day(DateTime day) {
    final start = _start;
    final value = DateTime.utc(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );
    _set(value, value.add(_end.difference(start)));
  }

  Future<void> _calendar(BuildContext context) async {
    final now = _now, start = _start;
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 2, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: start.isBefore(first)
          ? first
          : start.isAfter(last)
          ? last
          : start,
      firstDate: first,
      lastDate: last,
    );
    if (day != null && context.mounted && controller.alive) _day(day);
  }

  Future<void> _customDuration(BuildContext context) async {
    var hours = '${_end.difference(_start).inMinutes / 60}';
    final form = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom duration'),
        content: Form(
          key: form,
          child: TextFormField(
            key: const ValueKey('booking-custom-hours'),
            initialValue: hours,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hours',
              helperText: 'For example 1.5 for 1 hour 30 minutes',
            ),
            onChanged: (v) => hours = v,
            validator: (v) {
              final h = double.tryParse(v ?? '');
              return h == null || !h.isFinite || h * 60 < 1 || h > 744
                  ? 'Enter 1 minute to 31 days in hours.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (double.parse(hours) * 60).round());
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (minutes != null && context.mounted && controller.alive) {
      _set(_start, _start.add(Duration(minutes: minutes)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller, now = _now, start = _start, end = _end;
    final day = DateTime.utc(start.year, start.month, start.day);
    final minutes = start.hour * 60 + start.minute;
    final duration = end.difference(start);
    final localizations = MaterialLocalizations.of(context);
    String at(double value) => localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(day.add(Duration(minutes: value.round()))),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        activeTrackColor: const Color(0xFFE6EDF0),
        inactiveTrackColor: const Color(0xFFE6EDF0),
        activeTickMarkColor: const Color(0xFF8997A0),
        inactiveTickMarkColor: const Color(0xFF8997A0),
        thumbColor: catalogTeal,
      ),
      child: Slider(
        key: ValueKey(
          c.context!.route ? 'booking-pickup-time' : 'booking-start-time',
        ),
        value: minutes.toDouble().clamp(0, 1425),
        min: 0,
        max: 1425,
        divisions: 95,
        label: at(minutes.toDouble()),
        semanticFormatterCallback: at,
        onChanged: c.busy
            ? null
            : (value) {
                final next = day.add(
                  Duration(minutes: (value / 15).round() * 15),
                );
                _set(next, next.add(duration));
              },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                          label: Text(
                            localizations.formatMediumDate(
                              DateTime(now.year, now.month, now.day + i),
                            ),
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          selected:
                              c.start.isNotEmpty &&
                              DateUtils.isSameDay(
                                start,
                                DateTime(now.year, now.month, now.day + i),
                              ),
                          onSelected: c.busy
                              ? null
                              : (_) => _day(
                                  DateTime(now.year, now.month, now.day + i),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('booking-calendar'),
              tooltip: 'Choose another date',
              onPressed: c.busy ? null : () => _calendar(context),
              icon: const Icon(Icons.calendar_month, color: catalogTeal),
            ),
          ],
        ),
        if (start
                .difference(DateTime.utc(now.year, now.month, now.day))
                .inDays >
            3)
          Text(
            'Selected date: ${localizations.formatFullDate(start)}',
            style: const TextStyle(color: catalogMuted, fontSize: 12),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE6EDF0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final label = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, color: catalogTeal, size: 24),
                  const SizedBox(width: 8),
                  _TimeLabel(
                    title: c.context!.route ? 'Pickup time' : 'Preferred time',
                    value: at(minutes.toDouble()),
                  ),
                ],
              );
              return bounds.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 20
                  ? Row(
                      children: [
                        label,
                        const SizedBox(width: 6),
                        Expanded(child: slider),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [label, slider],
                    );
            },
          ),
        ),
        if (!c.context!.route) ...[
          const SizedBox(height: 12),
          const Text(
            'Duration',
            style: TextStyle(
              color: catalogInk,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final hours in [6, 12, 24, 48])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(hours < 24 ? '${hours}h' : '${hours ~/ 24}d'),
                      selected:
                          c.end.isNotEmpty &&
                          duration == Duration(hours: hours),
                      onSelected: c.busy
                          ? null
                          : (_) =>
                                _set(start, start.add(Duration(hours: hours))),
                    ),
                  ),
                ActionChip(
                  label: const Text('Custom'),
                  onPressed: c.busy ? null : () => _customDuration(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.title, required this.value});
  final String title, value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 280),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: catalogMuted, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            color: catalogInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
