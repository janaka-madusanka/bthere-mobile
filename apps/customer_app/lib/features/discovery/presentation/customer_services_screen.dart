import '../../../app/customer_theme.dart';
import '../../../app/widgets/customer_top_bar.dart';

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
    FocusScope.of(context).unfocus();
    setState(() => _expanded = _expanded == id ? null : id);
    if (_expanded != null) controller.loadOptions(id);
  }

  void _optionDetails(CustomerServiceOption option) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
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
              style: CustomerTypography.screen.copyWith(color: catalogInk),
            ),
            const SizedBox(height: 12),
            if (option.description case final description?)
              Text(
                description,
                style: CustomerTypography.body.copyWith(color: catalogMuted),
              ),
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
            top: false,
            bottom: false,
            child: Column(
              children: [
                const CustomerTopBar(),
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: CustomerColors.background,
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
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          key: const ValueKey(
                                            'customer-services-back',
                                          ),
                                          tooltip: 'Back to home',
                                          onPressed: () => context.canPop()
                                              ? context.pop()
                                              : context.go('/home'),
                                          icon: const Icon(
                                            Icons.arrow_back_rounded,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                CustomerColors.action,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Services',
                                            key: const ValueKey(
                                              'customer-services-title',
                                            ),
                                            style: CustomerTypography.screen
                                                .copyWith(
                                                  color: const Color(
                                                    0xFF101D42,
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE1F4F2),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Text(
                                            controller.serviceStage ==
                                                    DiscoveryStage.ready
                                                ? '${controller.services.length}'
                                                : '\u2014',
                                            style: CustomerTypography.section
                                                .copyWith(
                                                  color: CustomerColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      key: const ValueKey(
                                        'customer-service-search',
                                      ),
                                      controller: _search,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'Search services',
                                        filled: true,
                                        fillColor: Colors.white,
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: catalogTeal,
                                        ),
                                        suffixIcon: _search.text.isEmpty
                                            ? null
                                            : IconButton(
                                                tooltip: 'Clear service search',
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                ),
                                                onPressed: () =>
                                                    setState(_search.clear),
                                              ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFCADFE1),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: catalogTeal,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (controller.serviceStage ==
                                            DiscoveryStage.idle ||
                                        controller.serviceStage ==
                                            DiscoveryStage.loading)
                                      const _ServicesLoadingSkeleton()
                                    else if (controller.serviceStage !=
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
  ServiceAppearance _optionAppearance(CustomerServiceOption option) {
    final name = option.name.toLowerCase();
    return ServiceAppearance(
      catalogTeal,
      name.contains('hospital')
          ? Icons.local_hospital_outlined
          : name.contains('home')
          ? Icons.home_outlined
          : name.contains('ride') || name.contains('transport')
          ? Icons.directions_car_outlined
          : appearance.icon,
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1,
    shadowColor: const Color(0x100F666B),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: expanded ? const Color(0xFF8BCFC7) : const Color(0xFFE1EBEF),
        width: expanded ? 1.2 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Ink(
      decoration: BoxDecoration(
        gradient: expanded
            ? const LinearGradient(
                colors: [Color(0xFFEAF9F6), Color(0xFFF3FCFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              key: ValueKey('customer-category-${service.id}'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    CatalogIcon(
                      appearance: appearance,
                      url: service.iconUrl,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: CustomerTypography.section.copyWith(
                              color: const Color(0xFF101D42),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!{
                            'ELIGIBLE',
                            'CHECK_OPTION',
                          }.contains(service.accessStatus))
                            CatalogAccess(service: service),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: expanded
                            ? const Color(0xFFCFF3EF)
                            : const Color(0xFFF0FAF8),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: catalogTeal,
                          size: 23,
                        ),
                      ),
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
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Text(
                              reason,
                              style: CustomerTypography.compact.copyWith(
                                color: catalogMuted,
                              ),
                            ),
                          ),
                        Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE0EFEF)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              state.stage == DiscoveryStage.idle ||
                                  state.stage == DiscoveryStage.loading
                              ? const _ServicesLoadingSkeleton(options: true)
                              : state.stage != DiscoveryStage.ready ||
                                    state.options.isEmpty
                              ? CatalogStatus(
                                  options: true,
                                  loading:
                                      state.stage == DiscoveryStage.idle ||
                                      state.stage == DiscoveryStage.loading,
                                  failed: state.stage == DiscoveryStage.failure,
                                  empty: state.options.isEmpty,
                                  retry: retry,
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < state.options.length;
                                      index++
                                    ) ...[
                                      if (index > 0)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Divider(
                                            height: 1,
                                            color: Color(0xFFDCEEEE),
                                          ),
                                        ),
                                      InkWell(
                                        key: ValueKey(
                                          'customer-option-${state.options[index].id}',
                                        ),
                                        onTap: () =>
                                            onOption(state.options[index]),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              CatalogIcon(
                                                appearance: _optionAppearance(
                                                  state.options[index],
                                                ),
                                                url: state
                                                    .options[index]
                                                    .iconUrl,
                                                size: 34,
                                              ),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      state.options[index].name,
                                                      style: CustomerTypography
                                                          .card
                                                          .copyWith(
                                                            color: const Color(
                                                              0xFF101D42,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                    if (state
                                                            .options[index]
                                                            .access
                                                            .accessStatus !=
                                                        'ELIGIBLE')
                                                      CatalogAccess(
                                                        service: state
                                                            .options[index]
                                                            .access,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.chevron_right_rounded,
                                                color: catalogTeal,
                                                size: 22,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Static placeholders avoid extra animation work while catalog reads run.
class _ServicesLoadingSkeleton extends StatelessWidget {
  const _ServicesLoadingSkeleton({this.options = false});
  final bool options;
  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F0F1),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Semantics(
      label: options ? 'Loading service options' : 'Loading services',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          key: ValueKey(
            options
                ? 'service-options-loading-skeleton'
                : 'services-loading-skeleton',
          ),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < (options ? 3 : 4); i++)
              Container(
                margin: EdgeInsets.only(bottom: options ? 0 : 10),
                padding: EdgeInsets.all(options ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(options ? 0 : 18),
                  border: options
                      ? null
                      : Border.all(color: const Color(0xFFE1EBEF)),
                ),
                child: Row(
                  children: [
                    block(options ? 34 : 42, width: options ? 34 : 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: i.isEven ? .65 : .48,
                          child: block(options ? 14 : 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    block(20, width: 20),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
