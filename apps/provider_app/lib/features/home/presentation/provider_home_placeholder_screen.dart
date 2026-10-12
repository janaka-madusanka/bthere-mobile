import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

class ProviderHomePlaceholderScreen extends StatelessWidget {
  const ProviderHomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(BThereSpacing.lg),
          child: BThereStateView(
            title: 'B there Provider',
            message: 'Provider home',
          ),
        ),
      ),
    ),
  );
}
