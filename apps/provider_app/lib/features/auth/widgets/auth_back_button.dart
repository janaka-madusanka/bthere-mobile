import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: 'Back',
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_back),
    style: IconButton.styleFrom(
      minimumSize: const Size(BThereSpacing.xxxl, BThereSpacing.xxxl),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BThereRadius.control),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
  );
}
