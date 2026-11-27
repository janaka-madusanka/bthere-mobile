import '../../../app/widgets/market_banners.dart';
import '../../../app/widgets/customer_content_surface.dart';
import '../../../app/customer_theme.dart';
import '../../../app/widgets/customer_home_skeleton.dart';

import 'package:flutter/material.dart';

import '../../../app/widgets/customer_top_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/application/customer_profile_controller.dart';
import '../application/customer_discovery_controller.dart';
import '../domain/customer_discovery.dart';
import 'customer_discovery_style.dart';
import 'customer_bottom_navigation.dart';
import '../../booking/presentation/customer_bookings_screen.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  void _browse(BuildContext context, [int? id]) =>
      context.push(id == null ? '/services' : '/services?service=$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery = ref.watch(customerDiscoveryProvider);
    final profile = ref.watch(customerProfileControllerProvider);
    return Theme(
      data: CustomerTheme.authentication(),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: catalogTeal),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: const CustomerBottomNavigation(
            selected: CustomerNavigationTab.home,
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListenableBuilder(
              listenable: Listenable.merge([discovery, profile]),
              builder: (context, _) {
                final details = profile.profile?.details;
                final hour = DateTime.now().hour;
                final greeting = hour < 12
                    ? 'Good morning,'
                    : hour < 18
                    ? 'Good afternoon,'
                    : 'Good evening,';
                final name = details?.firstName.trim();
                return Column(
                  children: [
                    CustomerTopBar(extendBehindContent: true),
                    Expanded(
                      child: CustomerContentSurface(
                        color: CustomerColors.pageBackground,
                        child: RefreshIndicator(
                          onRefresh: discovery.loadServices,
                          child: SingleChildScrollView(
                            key: const ValueKey('customer-home-scroll'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 800,
                                ),
                                child:
                                    discovery.serviceStage ==
                                            DiscoveryStage.loading ||
                                        discovery.serviceStage ==
                                            DiscoveryStage.idle
                                    ? const CustomerHomeSkeleton()
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text.rich(
                                            TextSpan(
                                              text: '$greeting ',
                                              style: CustomerTypography.body
                                                  .copyWith(
                                                    color: catalogMuted,
                                                  ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      name == null ||
                                                          name.isEmpty
                                                      ? 'Welcome!'
                                                      : name,
                                                  style: CustomerTypography.card
                                                      .copyWith(
                                                        color: catalogInk,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (discovery.activeMarket
                                              case final market?)
                                            CustomerMarketBanners(
                                              marketId: market.id,
                                            ),
                                          _SectionHeading(
                                            title: 'Explore Services',
                                            onViewAll: () => _browse(context),
                                          ),
                                          const SizedBox(height: 9),
                                          if (discovery.serviceStage !=
                                                  DiscoveryStage.ready ||
                                              discovery.services.isEmpty)
                                            CatalogStatus(
                                              loading:
                                                  discovery.serviceStage ==
                                                      DiscoveryStage.loading ||
                                                  discovery.serviceStage ==
                                                      DiscoveryStage.idle,
                                              failed:
                                                  discovery.serviceStage ==
                                                  DiscoveryStage.failure,
                                              empty: discovery.services.isEmpty,
                                              retry: discovery.loadServices,
                                            )
                                          else
                                            _ServiceGrid(
                                              services: discovery.services
                                                  .take(8)
                                                  .toList(),
                                              onTap: (service) =>
                                                  _browse(context, service.id),
                                            ),
                                          const SizedBox(height: 18),
                                          _SectionHeading(
                                            title: 'Recent Services',
                                            onViewAll: () =>
                                                context.push('/bookings'),
                                          ),
                                          const SizedBox(height: 8),
                                          const CustomerRecentBookings(),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.onViewAll});
  final String title;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: CustomerTypography.section.copyWith(color: catalogInk),
        ),
      ),
      if (onViewAll != null)
        TextButton(
          onPressed: onViewAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all',
                style: CustomerTypography.compactStrong.copyWith(
                  color: catalogTeal,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_forward, color: catalogTeal, size: 18),
            ],
          ),
        ),
    ],
  );
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services, required this.onTap});
  final List<CustomerService> services;
  final ValueChanged<CustomerService> onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 20
          ? 2
          : 4;
      final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
      final height = 108 * MediaQuery.textScalerOf(context).scale(14) / 14;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < services.length; i++)
            SizedBox(
              width: width,
              height: height,
              child: _CategoryTile(
                service: services[i],
                index: i,
                onTap: () => onTap(services[i]),
              ),
            ),
        ],
      );
    },
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.service,
    required this.index,
    required this.onTap,
  });
  final CustomerService service;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final appearance = ServiceAppearance.forService(service, index);
    return Material(
      key: ValueKey('customer-service-${service.id}'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CatalogIcon(
                appearance: appearance,
                url: service.iconUrl,
                size: 54,
              ),
              const SizedBox(height: 7),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: CustomerTypography.compactStrong.copyWith(
                  color: catalogInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
