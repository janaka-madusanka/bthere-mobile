import 'package:flutter/material.dart';

import 'bthere_button.dart';

/// Full-width primary action with a reserved progress slot in both states.
class BTherePrimaryButton extends StatelessWidget {
  const BTherePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => BThereButton(
    label: label,
    onPressed: onPressed,
    loading: loading,
    fullWidth: true,
    leadingIcon: const SizedBox(width: 20, height: 20),
    trailingIcon: const SizedBox(width: 20, height: 20),
  );
}
