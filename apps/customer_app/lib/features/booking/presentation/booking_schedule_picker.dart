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
    if (controller.context!.minimumNoticeMinutes != null) {
      return controller.earliestScheduledStart;
    }
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
    final chosen =
        !controller.bookNow &&
            controller.context!.minimumNoticeMinutes != null &&
            start.isBefore(controller.earliestScheduledStart)
        ? controller.earliestScheduledStart
        : start;
    controller.start = MarketTime.local(chosen);
    if (!controller.context!.route) {
      controller.end = MarketTime.local(chosen.add(end.difference(start)));
    }
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
    final earliest = controller.context!.minimumNoticeMinutes != null
        ? controller.earliestScheduledStart
        : now;
    final first = DateTime(earliest.year, earliest.month, earliest.day);
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
              headerHeadlineStyle: CustomerTypography.screen,
              headerHelpStyle: CustomerTypography.card,
              weekdayStyle: CustomerTypography.compactStrong.copyWith(
                color: CustomerColors.secondaryText,
              ),
              dayStyle: CustomerTypography.body,
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
              yearStyle: CustomerTypography.body,
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
                textStyle: CustomerTypography.card,
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
                textStyle: CustomerTypography.card,
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
        title: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 23,
              color: CustomerColors.action,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Custom duration',
                style: CustomerTypography.screen.copyWith(
                  color: const Color(0xFF0C1248),
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
              Text(
                'Hours',
                style: CustomerTypography.compactStrong.copyWith(
                  color: const Color(0xFF0C1248),
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
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF5F9FA),
                  suffixText: 'hrs',
                  suffixStyle: CustomerTypography.compact.copyWith(
                    color: CustomerColors.secondaryText,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(color: Color(0xFFDFE9EC)),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(color: Color(0xFFDFE9EC)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                    borderSide: BorderSide(
                      color: CustomerColors.action,
                      width: 1.5,
                    ),
                  ),
                  errorMaxLines: 2,
                ),
                style: CustomerTypography.body.copyWith(
                  color: const Color(0xFF0C1248),
                ),
                onChanged: (v) => hours = v,
                validator: (v) {
                  final h = double.tryParse(v ?? '');
                  return h == null || !h.isFinite || h * 60 < 1 || h > 744
                      ? 'Enter 1 minute to 31 days in hours.'
                      : null;
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Example: 1.5 hours = 1 hour 30 minutes',
                style: CustomerTypography.compact.copyWith(
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
                  child: const Text('Cancel', style: CustomerTypography.card),
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
                  child: const Text('Apply', style: CustomerTypography.card),
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
    final modern = c.context!.minimumNoticeMinutes != null;
    final earliest = modern ? c.earliestScheduledStart : now;
    final firstDay = DateTime.utc(earliest.year, earliest.month, earliest.day);
    final step = modern ? 5 : 15;
    final lastMinute = modern ? 1435 : 1425;
    final minMinute = modern && day == firstDay
        ? earliest.hour * 60 + earliest.minute
        : 0;
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
        value: minutes.toDouble().clamp(
          minMinute.toDouble(),
          lastMinute.toDouble(),
        ),
        min: minMinute.toDouble(),
        max: lastMinute.toDouble(),
        divisions: lastMinute == minMinute
            ? null
            : (lastMinute - minMinute) ~/ step,
        label: at(minutes.toDouble()),
        semanticFormatterCallback: at,
        onChanged: c.busy
            ? null
            : (value) {
                final next = day.add(
                  Duration(minutes: (value / step).round() * step),
                );
                _set(next, next.add(duration));
              },
      ),
    );
    final chipStyle = Theme.of(context).chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: CustomerColors.selection,
      checkmarkColor: catalogTeal,
      labelStyle: CustomerTypography.compact.copyWith(color: catalogInk),
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
          if (c.context!.instantBooking) ...[
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('booking-book-now'),
                  label: const Text('Book now'),
                  selected: c.bookNow,
                  onSelected: c.busy ? null : (_) => c.chooseBookNow(true),
                ),
                ChoiceChip(
                  key: const ValueKey('booking-schedule-later'),
                  label: const Text('Schedule later'),
                  selected: !c.bookNow,
                  onSelected: c.busy ? null : (_) => c.chooseBookNow(false),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (c.bookNow)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Book now · Find an available provider for your request.',
                style: CustomerTypography.card,
              ),
            ),
          if (!c.bookNow) ...[
            if (modern && c.minimumNoticeMinutes > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Book at least ${c.minimumNoticeMinutes} minutes ahead.',
                  style: CustomerTypography.compact,
                ),
              ),
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
                                  firstDay.add(Duration(days: i)),
                                ),
                              ),
                              labelStyle: CustomerTypography.compactStrong,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              selected:
                                  c.start.isNotEmpty &&
                                  DateUtils.isSameDay(
                                    start,
                                    firstDay.add(Duration(days: i)),
                                  ),
                              onSelected: c.busy
                                  ? null
                                  : (_) =>
                                        _day(firstDay.add(Duration(days: i))),
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
                style: CustomerTypography.compact.copyWith(color: catalogMuted),
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
                  style: CustomerTypography.compact.copyWith(
                    color: CustomerColors.error,
                  ),
                ),
              ),
            ],
          ],
          if (!c.context!.route) ...[
            const SizedBox(height: 12),
            Text(
              'Duration',
              style: CustomerTypography.card.copyWith(color: catalogInk),
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
        Text(
          title,
          style: CustomerTypography.compact.copyWith(color: catalogMuted),
        ),
        Text(value, style: CustomerTypography.card.copyWith(color: catalogInk)),
      ],
    ),
  );
}
