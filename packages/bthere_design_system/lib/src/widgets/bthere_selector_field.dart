import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/bthere_radius.dart';
import '../theme/bthere_spacing.dart';
import 'bthere_field_group.dart';

class BThereSelectorOption<T> {
  const BThereSelectorOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// A validated, keyboard-accessible field with a mobile option sheet.
class BThereSelectorField<T> extends FormField<T> {
  const BThereSelectorField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.sheetTitle,
    required this.icon,
    required this.options,
    required this.onChanged,
    T? value,
    super.enabled = true,
    super.validator,
  }) : super(initialValue: value, builder: _buildField);

  final String label, placeholder, sheetTitle;
  final IconData icon;
  final List<BThereSelectorOption<T>> options;
  final ValueChanged<T>? onChanged;

  static Widget _buildField(FormFieldState<dynamic> state) =>
      (state as _SelectorFieldState<dynamic>).buildControl();

  @override
  FormFieldState<T> createState() => _SelectorFieldState<T>();
}

class _SelectorFieldState<T> extends FormFieldState<T> {
  bool _opening = false, _focused = false;
  final _fieldFocus = FocusNode();

  @override
  void dispose() {
    _fieldFocus.dispose();
    super.dispose();
  }

  @override
  BThereSelectorField<T> get widget => super.widget as BThereSelectorField<T>;

  @override
  void didUpdateWidget(covariant BThereSelectorField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }

  Future<void> _open() async {
    if (!widget.enabled || _opening || widget.options.isEmpty) return;
    FocusScope.of(context).unfocus();
    _fieldFocus.requestFocus();
    final options = List<BThereSelectorOption<T>>.of(widget.options);
    final currentValue = value;
    final title = widget.sheetTitle;
    setState(() => _opening = true);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;
    if (!widget.enabled) {
      setState(() => _opening = false);
      return;
    }
    final selected = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BThereRadius.surface),
        ),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              BThereSpacing.md,
              0,
              BThereSpacing.md,
              BThereSpacing.md,
            ),
            itemCount: options.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BThereSpacing.xs,
                    0,
                    BThereSpacing.xs,
                    BThereSpacing.md,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                );
              }
              final option = options[index - 1];
              final selected = option.value == currentValue;
              final colors = Theme.of(context).colorScheme;
              return Semantics(
                key: ValueKey('selector-option-${index - 1}'),
                selected: selected,
                button: true,
                child: ListTile(
                  minTileHeight: 56,
                  selected: selected,
                  selectedColor: colors.primary,
                  selectedTileColor: colors.primary.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BThereRadius.control),
                  ),
                  title: Text(option.label),
                  trailing: ExcludeSemantics(
                    child: Icon(
                      selected ? Icons.check : Icons.radio_button_unchecked,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    _fieldFocus.requestFocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (!mounted) return;
    setState(() => _opening = false);
    if (selected != null &&
        widget.enabled &&
        widget.options.any((option) => option.value == selected)) {
      didChange(selected);
      widget.onChanged?.call(selected);
    }
  }

  Widget buildControl() {
    final theme = Theme.of(context);
    String? selectedLabel;
    for (final option in widget.options) {
      if (option.value == value) selectedLabel = option.label;
    }
    return BThereFieldGroup(
      label: widget.label,
      child: Semantics(
        value: selectedLabel ?? widget.placeholder,
        hint: errorText,
        liveRegion: errorText != null,
        button: true,
        enabled: widget.enabled,
        onTap: widget.enabled ? _open : null,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(BThereRadius.control),
          onTap: widget.enabled ? _open : null,
          focusNode: _fieldFocus,
          canRequestFocus: widget.enabled,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: InputDecorator(
            isFocused: _focused || _opening,
            decoration: InputDecoration(
              enabled: widget.enabled,
              prefixIcon: Icon(widget.icon),
              suffixIcon: const Icon(Icons.expand_more),
              errorText: errorText,
            ),
            child: Text(
              selectedLabel ?? widget.placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selectedLabel == null
                  ? theme.inputDecorationTheme.hintStyle
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
