import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

class BookingCalendarDialog extends StatefulWidget {
  const BookingCalendarDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.currentDate,
  });
  final DateTime initialDate, firstDate, lastDate, currentDate;
  @override
  State<BookingCalendarDialog> createState() => _BookingCalendarDialogState();
}

class _BookingCalendarDialogState extends State<BookingCalendarDialog> {
  late DateTime _selected = widget.initialDate;
  bool _input = false;
  final _form = GlobalKey<FormState>();

  void _confirm() {
    if (_input) {
      if (!_form.currentState!.validate()) return;
      _form.currentState!.save();
    }
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateTheme = theme.datePickerTheme;
    return Dialog(
      key: const ValueKey('booking-calendar-dialog'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                color: CustomerColors.selection,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose service date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CustomerColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(_selected),
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: CustomerColors.text,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _input
                              ? 'Choose from calendar'
                              : 'Enter date',
                          onPressed: () => setState(() => _input = !_input),
                          icon: Icon(
                            _input
                                ? Icons.calendar_month_outlined
                                : Icons.edit_outlined,
                            color: CustomerColors.primary,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_input)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _form,
                    child: InputDatePickerFormField(
                      initialDate: _selected,
                      firstDate: widget.firstDate,
                      lastDate: widget.lastDate,
                      autofocus: true,
                      onDateSaved: (date) => _selected = date,
                    ),
                  ),
                )
              else
                // Native compact calendar keeps month/year navigation, semantics
                // and keyboard support without the fixed-height date-dialog shell.
                Theme(
                  data: ThemeData(
                    useMaterial3: false,
                    colorScheme: theme.colorScheme,
                    textTheme: theme.textTheme,
                    iconTheme: theme.iconTheme,
                    fontFamily: CustomerTypography.family,
                    datePickerTheme: dateTheme,
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    currentDate: widget.currentDate,
                    onDateChanged: (date) => setState(() => _selected = date),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: dateTheme.cancelButtonStyle?.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 52),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        style: dateTheme.confirmButtonStyle?.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 52),
                          ),
                        ),
                        onPressed: _confirm,
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
