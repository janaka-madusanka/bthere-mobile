import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../discovery/presentation/customer_discovery_style.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';
import '../../../app/customer_theme.dart';
import 'booking_calendar_dialog.dart';

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

  Future<void> showCalendar(BuildContext context) async {
    final now = _now, start = _start;
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(now.year + 2, now.month, now.day);
    final day = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        final child = BookingCalendarDialog(
          initialDate: start.isBefore(first)
              ? first
              : start.isAfter(last)
              ? last
              : start,
          firstDate: first,
          lastDate: last,
          currentDate: now,
        );
        final theme = CustomerTheme.authentication();
        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerBackgroundColor: CustomerColors.selection,
              headerForegroundColor: CustomerColors.text,
              headerHeadlineStyle: const TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
              headerHelpStyle: const TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: const TextStyle(
                color: CustomerColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dayStyle: const TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? CustomerColors.muted.withValues(alpha: .5)
                    : states.contains(WidgetState.selected)
                    ? Colors.white
                    : CustomerColors.text,
              ),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? CustomerColors.action
                    : Colors.transparent,
              ),
              dayShape: const WidgetStatePropertyAll(CircleBorder()),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : CustomerColors.action,
              ),
              todayBorder: const BorderSide(color: CustomerColors.action),
              yearStyle: const TextStyle(
                fontFamily: CustomerTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              subHeaderForegroundColor: CustomerColors.text,
              dividerColor: CustomerColors.border,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: CustomerColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: CustomerColors.action.withValues(alpha: .35),
                ),
                minimumSize: const Size(112, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontFamily: CustomerTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: CustomerColors.action,
                minimumSize: const Size(112, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontFamily: CustomerTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF5F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          child: child,
        );
      },
    );
    if (day != null && context.mounted && controller.alive) _day(day);
  }

  Future<void> showCustomDuration(BuildContext context) async {
    var hours = '${_end.difference(_start).inMinutes / 60}';
    final form = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        scrollable: true,
        title: const Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 23,
              color: CustomerColors.action,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Custom duration',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C1248),
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hours',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C1248),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('booking-custom-hours'),
                initialValue: hours,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFF5F9FA),
                  suffixText: 'hrs',
                  suffixStyle: TextStyle(
                    fontSize: 12,
                    color: CustomerColors.secondaryText,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(color: Color(0xFFDFE9EC)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(color: Color(0xFFDFE9EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(
                      color: CustomerColors.action,
                      width: 1.5,
                    ),
                  ),
                  errorMaxLines: 2,
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0C1248)),
                onChanged: (v) => hours = v,
                validator: (v) {
                  final h = double.tryParse(v ?? '');
                  return h == null || !h.isFinite || h * 60 < 1 || h > 744
                      ? 'Enter 1 minute to 31 days in hours.'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Example: 1.5 hours = 1 hour 30 minutes',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: CustomerColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(
                        context,
                        (double.parse(hours) * 60).round(),
                      );
                    }
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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
        trackHeight: 3,
        activeTrackColor: catalogTeal.withValues(alpha: .55),
        inactiveTrackColor: const Color(0xFFE6EDF0),
        activeTickMarkColor: const Color(0xFF8997A0),
        inactiveTickMarkColor: const Color(0xFF8997A0),
        thumbColor: catalogTeal,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
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
    final chipStyle = Theme.of(context).chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: CustomerColors.selection,
      checkmarkColor: catalogTeal,
      labelStyle: const TextStyle(
        fontFamily: CustomerTypography.family,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: catalogInk,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? catalogTeal.withValues(alpha: .65)
              : const Color(0xFFDFE9EC),
        ),
      ),
    );
    return ChipTheme(
      data: chipStyle,
      child: Column(
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
                              fontFamily: CustomerTypography.family,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                onPressed: c.busy ? null : () => showCalendar(context),
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
            key: const ValueKey('booking-preferred-time'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.startTimeError != null
                  ? CustomerColors.error.withValues(alpha: .04)
                  : const Color(0xFFF7FBFB),
              border: Border.all(
                color: c.startTimeError != null
                    ? CustomerColors.error
                    : const Color(0xFFE6EDF0),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final label = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: CustomerColors.selection,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: catalogTeal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TimeLabel(
                      title: c.context!.route
                          ? 'Pickup time'
                          : 'Preferred time',
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
          if (c.startTimeError ?? c.fieldErrors['Start time']
              case final String issue) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                issue,
                key: const ValueKey('booking-preferred-time-error'),
                style: const TextStyle(
                  color: CustomerColors.error,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (!c.context!.route) ...[
            const SizedBox(height: 12),
            const Text(
              'Duration',
              style: TextStyle(
                fontFamily: CustomerTypography.family,
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
                        label: Text(
                          hours < 24 ? '${hours}h' : '${hours ~/ 24}d',
                        ),
                        selected:
                            c.end.isNotEmpty &&
                            duration == Duration(hours: hours),
                        onSelected: c.busy
                            ? null
                            : (_) => _set(
                                start,
                                start.add(Duration(hours: hours)),
                              ),
                      ),
                    ),
                  ActionChip(
                    label: const Text('Custom'),
                    backgroundColor:
                        c.end.isNotEmpty &&
                            ![
                              6,
                              12,
                              24,
                              48,
                            ].any((h) => duration == Duration(hours: h))
                        ? CustomerColors.selection
                        : Colors.white,
                    onPressed: c.busy
                        ? null
                        : () => showCustomDuration(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
            fontFamily: CustomerTypography.family,
            color: catalogInk,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}
