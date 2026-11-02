import 'booking_validation_group.dart';
import 'booking_choice_tiles.dart';

import 'package:flutter/material.dart';

import '../application/customer_booking_controller.dart';
import '../../discovery/presentation/customer_discovery_style.dart';

class BookingProviderFilters extends StatelessWidget {
  const BookingProviderFilters({super.key, required this.controller});
  final CustomerBookingController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in c.context!.providerFilters)
          Padding(
            key: ValueKey('provider-filter-${field.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: BookingValidationGroup(
              key: ValueKey('provider-filter-validation-${field.id}'),
              error: c.fieldErrors[field.label],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!field.label.toLowerCase().contains('language') &&
                      (!field.options.every(
                            (o) => {'MALE', 'FEMALE'}.contains(o['value']),
                          ) ||
                          field.options.isEmpty))
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.label,
                            style: const TextStyle(
                              color: catalogInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              c.busy || !c.providerFilters.containsKey(field.id)
                              ? null
                              : () => c.edit(
                                  () => c.providerFilters.remove(field.id),
                                ),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  if (field.type == 'NUMBER')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final bound in ['minimum', 'maximum'])
                          SizedBox(
                            width: 130,
                            child: _FilterNumberInput(
                              key: ValueKey(
                                'provider-filter-${field.id}-$bound',
                              ),
                              initialValue: c.providerFilters[field.id] is Map
                                  ? '${(c.providerFilters[field.id] as Map)[bound] ?? ''}'
                                  : '',
                              enabled: !c.busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: bound == 'minimum'
                                    ? 'Minimum'
                                    : 'Maximum',
                              ),
                              onChanged: (v) => c.edit(
                                () => c.providerFilters[field.id] = {
                                  ...?(c.providerFilters[field.id] as Map?),
                                  bound: v,
                                },
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (field.type == 'BOOLEAN')
                    BookingChoiceTiles(
                      choices: const [
                        {'value': 'true', 'label': 'Yes'},
                        {'value': 'false', 'label': 'No'},
                      ],
                      selected: {
                        if (c.providerFilters[field.id] != null)
                          '${c.providerFilters[field.id]}',
                      },
                      enabled: !c.busy,
                      onChanged: (value, on) => c.edit(() {
                        if (on) {
                          c.providerFilters[field.id] = value == 'true';
                        } else {
                          c.providerFilters.remove(field.id);
                        }
                      }),
                    )
                  else
                    BookingChoiceTiles(
                      choices: field.options,
                      selected: Set<String>.from(
                        c.providerFilters[field.id] as List? ?? const [],
                      ),
                      enabled: !c.busy,
                      onChanged: (value, on) => c.edit(() {
                        final values = List<String>.from(
                          c.providerFilters[field.id] as List? ?? const [],
                        );
                        final gender = field.options.every(
                          (o) => {'MALE', 'FEMALE'}.contains(o['value']),
                        );
                        if (gender) values.clear();
                        if (on) {
                          values.add(value);
                        } else {
                          values.remove(value);
                        }
                        if (values.isEmpty) {
                          c.providerFilters.remove(field.id);
                        } else {
                          c.providerFilters[field.id] = values;
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterNumberInput extends StatefulWidget {
  const _FilterNumberInput({
    super.key,
    required this.initialValue,
    required this.enabled,
    required this.keyboardType,
    required this.decoration,
    required this.onChanged,
  });
  final String initialValue;
  final bool enabled;
  final TextInputType keyboardType;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;
  @override
  State<_FilterNumberInput> createState() => _FilterNumberInputState();
}

class _FilterNumberInputState extends State<_FilterNumberInput> {
  late final _text = TextEditingController(text: widget.initialValue);
  @override
  void didUpdateWidget(_FilterNumberInput old) {
    super.didUpdateWidget(old);
    if (_text.text != widget.initialValue) _text.text = widget.initialValue;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _text,
    enabled: widget.enabled,
    keyboardType: widget.keyboardType,
    decoration: widget.decoration,
    onChanged: widget.onChanged,
  );
}
