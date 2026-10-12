import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import '../../../core/presentation/branded_form_page.dart';

class ProviderHomeScreen extends StatelessWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BrandedFormPage(
    title: 'Welcome back',
    subtitle: 'Manage your services and activity from here.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(BThereSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.home_outlined,
              color: BThereColors.primaryAction,
              size: 32,
            ),
            const SizedBox(height: BThereSpacing.md),
            Text(
              'Home dashboard',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: BThereColors.textPrimary),
            ),
            const SizedBox(height: BThereSpacing.xs),
            const Text(
              'More provider insights and activity will appear here soon.',
              style: TextStyle(color: BThereColors.textSecondaryAccessible),
            ),
          ],
        ),
      ),
    ),
  );
}
