import '../../../app/customer_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/customer_discovery_controller.dart';
import '../domain/customer_discovery.dart';
import 'customer_discovery_style.dart';
import 'customer_bottom_navigation.dart';

class CustomerServicesScreen extends ConsumerStatefulWidget {
  const CustomerServicesScreen({super.key, this.initialServiceId});
  final int? initialServiceId;
  @override
  ConsumerState<CustomerServicesScreen> createState() =>
      _CustomerServicesScreenState();
}

class _CustomerServicesScreenState
    extends ConsumerState<CustomerServicesScreen> {
  final _search = TextEditingController();
  final _expandedKey = GlobalKey();
  int? _expanded;
  bool _scrolled = false;
  @override
  void initState() {
    super.initState();
    _expanded = widget.initialServiceId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(CustomerDiscoveryController controller, int id) {
    setState(() => _expanded = _expanded == id ? null : id);
    if (_expanded != null) controller.loadOptions(id);
  }

  void _optionDetails(CustomerServiceOption option) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              option.name,
              style: const TextStyle(
                color: catalogInk,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (option.description case final description?) Text(description),
            const SizedBox(height: 12),
            CatalogAccess(service: option.access),
            for (final reason in option.access.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(reason),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                context.push('/booking/${option.serviceId}/${option.id}');
              },
              child: const Text('Continue with this service'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(customerDiscoveryProvider);
    return Theme(
      data: CustomerTheme.authentication(),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: catalogGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: const CustomerBottomNavigation(
            selected: CustomerNavigationTab.services,
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 48, 12),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('customer-services-back'),
                        tooltip: 'Back to home',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/home'),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Get a Service',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: catalogPaper,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        final query = _search.text.trim().toLowerCase();
                        final services = controller.services
                            .where(
                              (service) =>
                                  service.name.toLowerCase().contains(query) ||
                                  (service.description?.toLowerCase().contains(
                                        query,
                                      ) ??
                                      false),
                            )
                            .toList();
                        final expanded = _expanded;
                        if (expanded != null &&
                            controller.services.any(
                              (item) => item.id == expanded,
                            )) {
                          final stage = controller.optionsFor(expanded).stage;
                          if (stage == DiscoveryStage.idle) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _expanded == expanded) {
                                controller.loadOptions(expanded);
                              }
                            });
                          }
                          if (!_scrolled && stage == DiscoveryStage.ready) {
                            _scrolled = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final target = _expandedKey.currentContext;
                              if (mounted &&
                                  target != null &&
                                  controller.services.indexWhere(
                                        (service) => service.id == expanded,
                                      ) >
                                      1) {
                                Scrollable.ensureVisible(
                                  target,
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 240),
                                  alignment: .05,
                                );
                              }
                            });
                          }
                        }
                        return RefreshIndicator(
                          onRefresh: controller.loadServices,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Choose service category',
                                      style: TextStyle(
                                        color: catalogInk,
                                        fontSize: 24,
                                        height: 1.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap a category to see available services.',
                                      style: TextStyle(
                                        color: catalogMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextField(
                                      key: const ValueKey(
                                        'customer-service-search',
                                      ),
                                      controller: _search,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText: 'Search services...',
                                        prefixIcon: Icon(Icons.search_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (controller.serviceStage !=
                                            DiscoveryStage.ready ||
                                        controller.services.isEmpty)
                                      CatalogStatus(
                                        loading:
                                            controller.serviceStage ==
                                                DiscoveryStage.idle ||
                                            controller.serviceStage ==
                                                DiscoveryStage.loading,
                                        failed:
                                            controller.serviceStage ==
                                            DiscoveryStage.failure,
                                        empty: controller.services.isEmpty,
                                        retry: controller.loadServices,
                                      )
                                    else if (services.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'No matching services',
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else
                                      for (final service in services)
                                        Padding(
                                          key: _expanded == service.id
                                              ? _expandedKey
                                              : null,
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _ServiceAccordion(
                                            service: service,
                                            appearance:
                                                ServiceAppearance.forService(
                                                  service,
                                                  controller.services.indexOf(
                                                    service,
                                                  ),
                                                ),
                                            expanded: _expanded == service.id,
                                            state: controller.optionsFor(
                                              service.id,
                                            ),
                                            onTap: () =>
                                                _open(controller, service.id),
                                            retry: () => controller.loadOptions(
                                              service.id,
                                              retry: true,
                                            ),
                                            onOption: _optionDetails,
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceAccordion extends StatelessWidget {
  const _ServiceAccordion({
    required this.service,
    required this.appearance,
    required this.expanded,
    required this.state,
    required this.onTap,
    required this.retry,
    required this.onOption,
  });
  final CustomerService service;
  final ServiceAppearance appearance;
  final bool expanded;
  final CustomerOptionsState state;
  final VoidCallback onTap, retry;
  final ValueChanged<CustomerServiceOption> onOption;
  @override
  Widget build(BuildContext context) => Material(
    color: appearance.color.withValues(alpha: .055),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(19),
      side: BorderSide(color: appearance.color.withValues(alpha: .1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: InkWell(
            key: ValueKey('customer-category-${service.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CatalogIcon(
                    appearance: appearance,
                    url: service.iconUrl,
                    size: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            color: catalogInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (service.accessStatus != 'ELIGIBLE')
                          CatalogAccess(service: service),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: appearance.color,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final reason in service.reasons)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                          child: Text(
                            reason,
                            style: const TextStyle(
                              color: catalogMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (state.stage != DiscoveryStage.ready ||
                          state.options.isEmpty)
                        CatalogStatus(
                          options: true,
                          loading:
                              state.stage == DiscoveryStage.idle ||
                              state.stage == DiscoveryStage.loading,
                          failed: state.stage == DiscoveryStage.failure,
                          empty: state.options.isEmpty,
                          retry: retry,
                        )
                      else
                        for (final option in state.options)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Material(
                              color: Colors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                key: ValueKey('customer-option-${option.id}'),
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => onOption(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      CatalogIcon(
                                        appearance: appearance,
                                        url: option.iconUrl,
                                        size: 38,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.name,
                                              style: const TextStyle(
                                                color: catalogInk,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (option.access.accessStatus !=
                                                'ELIGIBLE')
                                              CatalogAccess(
                                                service: option.access,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 19,
                                        color: catalogMuted,
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
      ],
    ),
  );
}
