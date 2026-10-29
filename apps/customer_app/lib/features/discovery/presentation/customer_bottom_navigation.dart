import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

enum CustomerNavigationTab {
  home('Home'),
  opportunities('Opportunities'),
  services('Services'),
  messages('Messages'),
  wallet('Wallet');

  const CustomerNavigationTab(this.label);
  final String label;
  String asset(bool selected) =>
      'assets/icons/navigation/$name${selected ? '_selected' : ''}.svg';
}

/// Main Customer destinations, with the system gesture area kept clear.
class CustomerBottomNavigation extends StatelessWidget {
  const CustomerBottomNavigation({super.key, required this.selected});
  final CustomerNavigationTab selected;

  void _select(BuildContext context, CustomerNavigationTab tab) {
    if (tab == selected) return;
    switch (tab) {
      case CustomerNavigationTab.home:
        context.go('/home');
      case CustomerNavigationTab.services:
        context.push('/services');
      case CustomerNavigationTab.wallet:
        context.go('/wallet');
      default:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('${tab.label} coming soon.')));
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('customer-bottom-navigation'),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF00666B), Color(0xFF00878C), Color(0xFF005E63)],
      ),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
          // Large labels remain readable and scroll instead of being clipped.
          final width = math.max(
            bounds.maxWidth / 5,
            scale > 1.3 ? 78 * scale : 0.0,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in CustomerNavigationTab.values)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      label: tab.label,
                      button: true,
                      selected: tab == selected,
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('customer-nav-${tab.name}'),
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _select(context, tab),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 50,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: tab == selected
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        tab.asset(tab == selected),
                                        width: 24,
                                        height: 24,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: bounds.maxWidth < 360
                                          ? 9.5
                                          : 11,
                                      height: 1.3,
                                      fontWeight: tab == selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
