import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import '../domain/provider_service_status.dart';

/// All badge and attention-tile colors are presentation mappings only.
class ServiceStatusStyle {
  const ServiceStatusStyle(
    this.foreground,
    this.background,
    this.icon,
    this.tileSurface,
    this.tileBorder,
  );
  final Color foreground, background, tileSurface, tileBorder;
  final IconData icon;

  factory ServiceStatusStyle.forStatus(ProviderServiceStatus? status) {
    final (foreground, background, icon) = switch (status) {
      ProviderServiceStatus.available || ProviderServiceStatus.approved => (
        BThereColors.primary,
        BThereColors.green.withValues(alpha: .16),
        Icons.check_circle_outline,
      ),
      ProviderServiceStatus.setupRequired => (
        const Color(0xFF85521A),
        const Color(0xFFFFF1DE),
        Icons.info_outline,
      ),
      ProviderServiceStatus.pendingApproval => (
        const Color(0xFF735A0C),
        const Color(0xFFFFF6D8),
        Icons.schedule,
      ),
      ProviderServiceStatus.rejected => (
        BThereColors.errorText,
        BThereColors.errorContainer,
        Icons.error_outline,
      ),
      ProviderServiceStatus.inactive || null => (
        BThereColors.textSecondaryAccessible,
        BThereColors.divider,
        Icons.pause_circle_outline,
      ),
    };
    final attention = status == ProviderServiceStatus.setupRequired;
    return ServiceStatusStyle(
      foreground,
      background,
      icon,
      attention ? const Color(0xFFFFFCF7) : BThereColors.surface,
      attention ? const Color(0xFFEAD8BE) : BThereColors.border,
    );
  }
}
