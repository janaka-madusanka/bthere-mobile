import 'package:flutter/material.dart';

import '../router/app_routes.dart';

/// The router and navigation bar share this ordered top-level configuration.
enum ProviderTab {
  home(AppRoutes.home, 'Home', Icons.home_outlined, Icons.home, null),
  services(
    AppRoutes.services,
    'Services',
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
    null,
  ),
  requests(
    AppRoutes.requests,
    'Opportunities',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    'Your service requests will appear here.',
  ),
  messages(
    AppRoutes.messages,
    'Messages',
    Icons.chat_bubble_outline,
    Icons.chat_bubble,
    'Your conversations will appear here.',
  ),
  profile(
    AppRoutes.account,
    'Profile',
    Icons.person_outline,
    Icons.person,
    null,
  );

  const ProviderTab(
    this.path,
    this.label,
    this.icon,
    this.selectedIcon,
    this.description,
  );
  final String path, label;
  final IconData icon, selectedIcon;
  final String? description;
}
