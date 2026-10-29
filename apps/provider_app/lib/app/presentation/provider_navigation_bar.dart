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
    (ProviderTab.wallet, 'wallet'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00888C), Color(0xFF00656B)],
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
    final icon = SvgPicture.asset(
      'assets/navigation/$asset${selected ? '_selected' : ''}.svg',
      width: 26,
      height: 26,
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
                child: Center(child: icon),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: BThereTypography.fontFamily,
                  fontSize: 10,
                  height: 1.8,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
