import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import '../../core/presentation/branded_form_page.dart';
import 'provider_tabs.dart';

/// Presentation only; no repository, account data or network dependencies.
class ProviderPlaceholderScreen extends StatelessWidget {
  const ProviderPlaceholderScreen({super.key, required this.tab});
  final ProviderTab tab;

  @override
  Widget build(BuildContext context) => BrandedFormPage(
    title: tab.label,
    subtitle: tab.description,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(BThereSpacing.xxl),
        child: ExcludeSemantics(
          child: Icon(tab.icon, color: BThereColors.primaryAction, size: 48),
        ),
      ),
    ),
  );
}
