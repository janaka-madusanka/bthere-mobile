import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

/// Reserve the progress slot in both states so large-text buttons do not jump.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.loading,
  });
  final String label;
  final VoidCallback onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) =>
      BTherePrimaryButton(label: label, onPressed: onPressed, loading: loading);
}
