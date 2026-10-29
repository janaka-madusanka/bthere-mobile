import 'package:flutter/material.dart';

import '../../../app/customer_theme.dart';

class BookingChoiceTiles extends StatelessWidget {
  const BookingChoiceTiles({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });
  final List<Map<String, String>> choices;
  final Set<String> selected;
  final void Function(String, bool) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          MediaQuery.textScalerOf(context).scale(14) > 20 ||
              bounds.maxWidth < 280
          ? 1
          : choices.length == 3
          ? 3
          : 2;
      final width = (bounds.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in choices)
            SizedBox(
              width: width,
              child: Semantics(
                selected: selected.contains(choice['value']),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    backgroundColor: selected.contains(choice['value'])
                        ? CustomerColors.selection
                        : Colors.white,
                    foregroundColor: selected.contains(choice['value'])
                        ? CustomerColors.action
                        : CustomerColors.text,
                    side: BorderSide(
                      color: selected.contains(choice['value'])
                          ? CustomerColors.action
                          : CustomerColors.border,
                    ),
                    textStyle: CustomerTypography.compact,
                  ),
                  onPressed: enabled
                      ? () => onChanged(
                          choice['value']!,
                          !selected.contains(choice['value']),
                        )
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ({'MALE', 'FEMALE'}.contains(choice['value'])) ...[
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 6),
                      ],
                      if (selected.contains(choice['value'])) ...[
                        const Icon(Icons.check, size: 15),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          choice['label']!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
