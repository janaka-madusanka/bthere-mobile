import 'package:flutter/material.dart';

import '../theme/bthere_spacing.dart';

enum BThereFieldLabelPlacement { floating, above }

/// Generic form control; validation and password visibility belong to callers.
class BThereTextField extends StatelessWidget {
  const BThereTextField({
    super.key,
    this.label,
    this.minLines,
    this.maxLines = 1,
    this.hint,
    this.labelPlacement = BThereFieldLabelPlacement.floating,
    this.helperText,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.autocorrect,
    this.enableSuggestions,
    this.enabled = true,
    this.validator,
    this.errorText,
    this.prefix,
    this.suffix,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.autovalidateMode,
  });
  final int? minLines;
  final int? maxLines;
  final String? label;
  final String? hint;
  final BThereFieldLabelPlacement labelPlacement;
  final String? helperText;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  /// Override for secure entry that remains secure when visibility changes.
  final bool? autocorrect;
  final bool? enableSuggestions;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final above =
        labelPlacement == BThereFieldLabelPlacement.above && label != null;
    final field = TextFormField(
      minLines: minLines,
      maxLines: maxLines,
      textAlign: textAlign,
      style: textStyle,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      enableSuggestions: enableSuggestions ?? !obscureText,
      autocorrect: autocorrect ?? !obscureText,
      decoration: InputDecoration(
        labelText: above ? null : label,
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 3,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
    if (!above) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(label!, style: Theme.of(context).textTheme.labelMedium),
        ),
        const SizedBox(height: BThereSpacing.xs),
        Semantics(label: label, child: field),
      ],
    );
  }
}
