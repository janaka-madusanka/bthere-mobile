import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'provider_tabs.dart';

/// Shared navigation from Figma's Bottom navigation component (364:3400).
/// Branch indices stay aligned with the router; visual order follows Figma.
class ProviderNavigationBar extends StatelessWidget {
  const ProviderNavigationBar({
    super.key,
    required this.onSelect,
    this.selectedIndex = 0,
  });

  final ValueChanged<int> onSelect;
  final int selectedIndex;

  static const _destinations = [
    (ProviderTab.home, 'home'),
    (ProviderTab.requests, 'opportunities'),
    (ProviderTab.services, 'services'),
    (ProviderTab.messages, 'messages'),
    (ProviderTab.profile, 'profile'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(-.04, -.2),
        radius: .75,
        colors: [Color(0xFF008F93), Color(0xFF007277), Color(0xFF00555B)],
        stops: [0, .5, 1],
      ),
    ),
    // The device supplies its own gesture indicator and bottom inset.
    child: SafeArea(
      top: false,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 430,
          child: Padding(
            padding: const EdgeInsets.all(16).copyWith(left: 14, right: 14),
            child: Row(
              children: [
                for (final (position, destination)
                    in _destinations.indexed) ...[
                  if (position > 0) const SizedBox(width: 10),
                  _destination(destination.$1, destination.$2, position),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _destination(ProviderTab tab, String asset, int position) {
    final selected = tab.index == selectedIndex;
    final size = tab == ProviderTab.profile
        ? 33.0
        : tab == ProviderTab.requests && selected
        ? 27.0
        : 26.0;
    final icon = SvgPicture.asset(
      'assets/navigation/$asset${selected ? '_selected' : ''}.svg',
      width: tab == ProviderTab.profile && selected ? 24 : size,
      height: tab == ProviderTab.profile && selected ? 25 : size,
    );
    return Semantics(
      key: ValueKey('provider-tab-${tab.index}'),
      button: true,
      selected: selected,
      label: '${tab.label}\nTab ${position + 1} of 5',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelect(tab.index),
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 33,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: tab == ProviderTab.profile && selected
                      ? SizedBox(
                          width: 33,
                          height: 33,
                          child: Stack(
                            children: [
                              Positioned(left: 5, top: 5, child: icon),
                            ],
                          ),
                        )
                      : icon,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: BThereTypography.fontFamily,
                  fontSize: 10,
                  height: 1.8,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
