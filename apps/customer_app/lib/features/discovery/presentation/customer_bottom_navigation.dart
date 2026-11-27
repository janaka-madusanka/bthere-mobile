import '../../../app/customer_theme.dart';
import '../../../app/customer_providers.dart';
import '../../booking/presentation/customer_payment_requests.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CustomerNavigationTab {
  home('Home'),
  opportunities('Booking'),
  services('Services'),
  messages('Messages'),
  wallet('Wallet'),
  profile('Profile');

  CustomerNavigationTab(this.label);
  final String label;
  String asset(bool selected) =>
      'assets/icons/navigation/${this == opportunities ? 'booking' : name}${selected ? '_selected' : ''}.svg';
}

// Cosmetic position only; shared across route instances, never persisted.
final _navigationMotionProvider = Provider((ref) => _NavigationMotion());

class _NavigationMotion {
  double? position;
}

/// Main Customer destinations, with the system gesture area kept clear.
class CustomerBottomNavigation extends ConsumerWidget {
  const CustomerBottomNavigation({
    super.key,
    required this.selected,
    this.onSelectedTap,
    this.surfaceColor = CustomerColors.surface,
  });
  final CustomerNavigationTab? selected;
  final VoidCallback? onSelectedTap;
  final Color surfaceColor;

  void _select(BuildContext context, CustomerNavigationTab tab) {
    if (tab == selected) {
      onSelectedTap?.call();
      return;
    }
    switch (tab) {
      case CustomerNavigationTab.home:
        context.go('/home');
      case CustomerNavigationTab.services:
        context.go('/services');
      case CustomerNavigationTab.wallet:
        context.go('/wallet');
      case CustomerNavigationTab.opportunities:
        context.go('/opportunities');
      case CustomerNavigationTab.messages:
        context.go('/messages');
      case CustomerNavigationTab.profile:
        context.go('/account');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = selected == null ? -1 : destinations.indexOf(selected!);
    if (target < 0) return _build(context, 0);
    final motion = ref.read(_navigationMotionProvider);
    final start = motion.position ?? target.toDouble();
    motion.position ??= start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ref.watch(customerConfigProvider) != null)
          const CustomerPaymentRequests(compact: true),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: start, end: target.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          builder: (context, position, _) {
            motion.position = position;
            return _build(context, position);
          },
        ),
      ],
    );
  }

  static const destinations = [
    CustomerNavigationTab.home,
    CustomerNavigationTab.opportunities,
    CustomerNavigationTab.services,
    CustomerNavigationTab.wallet,
  ];

  Widget _build(
    BuildContext context,
    double position,
  ) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Material(
      key: const ValueKey('customer-bottom-navigation'),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context);
          final inset = MediaQuery.paddingOf(context).bottom;
          final width = math.max(
            bounds.maxWidth,
            scale.scale(11) > 17
                ? destinations.length * 72 * scale.scale(11) / 11
                : 0.0,
          );
          final itemWidth = width / destinations.length;
          final height = 50 + scale.scale(11) * 1.3;
          final active = selected != null && destinations.contains(selected);
          return RepaintBoundary(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: height + inset + 10,
                child: Stack(
                  children: [
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SizedBox(
                        height: .5,
                        child: ColoredBox(color: Color(0xFFEDF1F3)),
                      ),
                    ),
                    if (active)
                      Positioned(
                        left: position * itemWidth + 7,
                        top: 6,
                        width: itemWidth - 14,
                        height: height - 2,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: const ValueKey(
                              'customer-selected-tab-indicator',
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F4F3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < destinations.length; i++)
                      Positioned(
                        left: i * itemWidth,
                        width: itemWidth,
                        top: 4,
                        height: height + 4,
                        child: Semantics(
                          label: destinations[i].label,
                          button: true,
                          selected: destinations[i] == selected,
                          child: ExcludeSemantics(
                            child: InkWell(
                              key: ValueKey(
                                'customer-nav-${destinations[i].name}',
                              ),
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              splashFactory: NoSplash.splashFactory,
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _select(context, destinations[i]),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    key: ValueKey(
                                      'customer-nav-icon-${destinations[i].name}',
                                    ),
                                    width: 22,
                                    height: 22,
                                    child:
                                        destinations[i] ==
                                            CustomerNavigationTab.profile
                                        ? Icon(
                                            Icons.person_outline_rounded,
                                            size: 22,
                                            color: destinations[i] == selected
                                                ? const Color(0xFF007F85)
                                                : const Color(0xFF607D86),
                                          )
                                        : SvgPicture.asset(
                                            destinations[i].asset(false),
                                            width: 22,
                                            height: 22,
                                            colorFilter: ColorFilter.mode(
                                              destinations[i] == selected
                                                  ? const Color(0xFF007F85)
                                                  : const Color(0xFF607D86),
                                              BlendMode.srcIn,
                                            ),
                                            excludeFromSemantics: true,
                                          ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    destinations[i].label,
                                    maxLines: 1,
                                    style: CustomerTypography.compact.copyWith(
                                      fontSize: 11,
                                      height: 1.3,
                                      color: destinations[i] == selected
                                          ? const Color(0xFF006D75)
                                          : const Color(0xFF607D86),
                                      fontWeight: destinations[i] == selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
