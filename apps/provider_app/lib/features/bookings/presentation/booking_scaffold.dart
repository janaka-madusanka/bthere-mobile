import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';

import '../../home/presentation/provider_home_widgets.dart';

const bookingInk = Color(0xFF0B3037);
const bookingMuted = Color(0xFF687B83);
const bookingTeal = Color(0xFF008F95);

/// Shared header, native system insets, and rounded content from the provider UI.
class BookingScaffold extends StatelessWidget {
  const BookingScaffold({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'PublicSans',
        bodyColor: bookingInk,
        displayColor: bookingInk,
      ),
    ),
    child: DecoratedBox(
      decoration: homeGradient,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HomeScale(child: _BookingHeader()),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: ColoredBox(
                  color: const Color(0xFFFDFDFE),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'PublicSans',
                      color: bookingInk,
                      fontSize: 14,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: Stack(
      children: [
        Positioned(
          left: -4,
          top: -100,
          width: 144,
          height: 144,
          child: SvgPicture.asset('assets/opportunities/imgBrandGlow.svg'),
        ),
        const Positioned(
          left: 25.8,
          top: 8,
          width: 84,
          height: 31,
          child: ProviderHeaderLogo(),
        ),
        Positioned(
          left: 326,
          top: 0,
          child: IconButton(
            tooltip: 'Opportunities',
            onPressed: () => context.go(AppRoutes.requests),
            icon: SvgPicture.asset(
              'assets/opportunities/imgNotifications.svg',
              width: 33,
              height: 33,
            ),
          ),
        ),
        Positioned(
          left: 372,
          top: 0,
          child: IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go(AppRoutes.account),
            icon: SvgPicture.asset(
              'assets/opportunities/imgAccountProfile.svg',
              width: 32,
              height: 32,
            ),
          ),
        ),
      ],
    ),
  );
}

class BookingFilters extends StatelessWidget {
  const BookingFilters({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, label) in labels.indexed) ...[
        if (index > 0) const SizedBox(width: 4),
        Expanded(
          child: Semantics(
            selected: index == selected,
            button: true,
            child: Material(
              color: index == selected
                  ? const Color(0xFFDDF5F3)
                  : const Color(0xFFF5F5F8),
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                onTap: () => onSelect(index),
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.4,
                      fontWeight: FontWeight.w700,
                      color: index == selected ? bookingTeal : bookingMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
