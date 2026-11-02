import '../../../app/customer_theme.dart';

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
                    CustomerTopBar(photo: safeImageUrl(details?.profilePhoto)),
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(color: catalogPaper),
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
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          greeting,
                                          style: const TextStyle(
                                            color: catalogMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          name == null || name.isEmpty
                                              ? 'Welcome!'
                                              : name,
                                          style: const TextStyle(
                                            color: catalogInk,
                                            fontSize: 22,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _ServiceHero(onTap: () => _browse(context)),
                                    const SizedBox(height: 15),
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
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.only(
                                        left: 15,
                                        right: 8,
                                        top: 12,
                                        bottom: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDF9FD),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                            color: Color(0xFF0AA6DD),
                                            size: 34,
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Need help regularly?',
                                                  style: TextStyle(
                                                    color: catalogInk,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Recurring services are coming soon.',
                                                  style: TextStyle(
                                                    color: catalogMuted,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 82,
                                            height: 70,
                                            child: Transform.rotate(
                                              angle: .12,
                                              child: const CareBee(
                                                sleeping: true,
                                              ),
                                            ),
                                          ),
                                        ],
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('customer-find-help'),
    color: const Color(0xFFE8F8F5),
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: largeText ? .2 : 1,
                    child: Image.asset(
                      'assets/illustrations/get_a_service.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: largeText ? double.infinity : bounds.maxWidth * .58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GET A SERVICE',
                        style: TextStyle(
                          color: catalogMuted,
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Find the right help, right when you need it',
                        style: TextStyle(
                          color: catalogInk,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: catalogTeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
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
          style: const TextStyle(
            color: catalogInk,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      if (onViewAll != null)
        TextButton(
          onPressed: onViewAll,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View all',
                style: TextStyle(
                  color: catalogTeal,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.arrow_forward, color: catalogTeal, size: 18),
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
      color: appearance.color.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CatalogIcon(
                appearance: appearance,
                url: service.iconUrl,
                size: 45,
              ),
              const SizedBox(height: 7),
              Text(
                service.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: catalogInk,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
