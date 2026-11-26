import '../../../app/widgets/customer_content_surface.dart';
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
  final _target = GlobalKey();
  final _showAll = <int>{};
  bool _scrolled = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialServiceId != null) _showAll.add(widget.initialServiceId!);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      child: Scaffold(
        backgroundColor: catalogTeal,
        bottomNavigationBar: const CustomerBottomNavigation(
          selected: CustomerNavigationTab.services,
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              const CustomerTopBar(extendBehindContent: true),
              Expanded(
                child: CustomerContentSurface(
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final query = _search.text.trim().toLowerCase();
                      final idle = controller.services
                          .where(
                            (s) =>
                                controller.optionsFor(s.id).stage ==
                                DiscoveryStage.idle,
                          )
                          .toList();
                      if (idle.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          for (final service in idle) {
                            controller.loadOptions(service.id);
                          }
                        });
                      }
                      if (!_scrolled &&
                          widget.initialServiceId != null &&
                          controller
                                  .optionsFor(widget.initialServiceId!)
                                  .stage ==
                              DiscoveryStage.ready) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted ||
                              _scrolled ||
                              _target.currentContext == null) {
                            return;
                          }
                          _scrolled = true;
                          Scrollable.ensureVisible(
                            _target.currentContext!,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                          );
                        });
                      }
                      final services = controller.services
                          .where(
                            (s) =>
                                query.isEmpty ||
                                s.name.toLowerCase().contains(query) ||
                                (s.description?.toLowerCase().contains(query) ??
                                    false) ||
                                controller
                                    .optionsFor(s.id)
                                    .options
                                    .any(
                                      (o) =>
                                          o.name.toLowerCase().contains(query),
                                    ),
                          )
                          .toList();
                      return RefreshIndicator(
                        onRefresh: controller.loadServices,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    key: const ValueKey(
                                      'customer-service-search',
                                    ),
                                    controller: _search,
                                    style: CustomerTypography.body.copyWith(
                                      color: CustomerColors.text,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Search services',
                                      hintStyle: CustomerTypography.compact
                                          .copyWith(color: catalogMuted),
                                      filled: true,
                                      fillColor: const Color(0xFFF0F5F5),
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 13,
                                          ),
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        color: catalogMuted,
                                        size: 20,
                                      ),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear service search',
                                              onPressed: () =>
                                                  setState(_search.clear),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 18,
                                              ),
                                            ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(28),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  if (controller.serviceStage ==
                                          DiscoveryStage.loading ||
                                      controller.serviceStage ==
                                          DiscoveryStage.idle)
                                    const _ServicesLoadingSkeleton()
                                  else if (controller.serviceStage !=
                                          DiscoveryStage.ready ||
                                      controller.services.isEmpty)
                                    CatalogStatus(
                                      loading: false,
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
                                      _ServiceOptionGroup(
                                        key:
                                            widget.initialServiceId ==
                                                service.id
                                            ? _target
                                            : ValueKey(
                                                'service-group-${service.id}',
                                              ),
                                        service: service,
                                        state: controller.optionsFor(
                                          service.id,
                                        ),
                                        query: query,
                                        index: controller.services.indexOf(
                                          service,
                                        ),
                                        showAll:
                                            _showAll.contains(service.id) ||
                                            query.isNotEmpty,
                                        onSeeAll: () => setState(() {
                                          if (!_showAll.add(service.id)) {
                                            _showAll.remove(service.id);
                                          }
                                        }),
                                        retry: () => controller.loadOptions(
                                          service.id,
                                          retry: true,
                                        ),
                                        onOption: _optionDetails,
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
    );
  }
}

class _ServiceOptionGroup extends StatelessWidget {
  const _ServiceOptionGroup({
    super.key,
    required this.service,
    required this.state,
    required this.index,
    required this.query,
    required this.showAll,
    required this.onSeeAll,
    required this.retry,
    required this.onOption,
  });
  final CustomerService service;
  final CustomerOptionsState state;
  final int index;
  final String query;
  final bool showAll;
  final VoidCallback onSeeAll, retry;
  final ValueChanged<CustomerServiceOption> onOption;
  @override
  Widget build(BuildContext context) {
    final appearance = ServiceAppearance.forService(service, index);
    final categoryMatches =
        service.name.toLowerCase().contains(query) ||
        (service.description?.toLowerCase().contains(query) ?? false);
    final options = state.options
        .where(
          (o) =>
              query.isEmpty ||
              categoryMatches ||
              o.name.toLowerCase().contains(query),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatalogIcon(
                appearance: appearance,
                url: service.iconUrl,
                size: 28,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  service.name,
                  key: ValueKey('customer-category-${service.id}'),
                  style: CustomerTypography.section.copyWith(
                    color: CustomerColors.text,
                  ),
                ),
              ),
              if (options.length > 4)
                TextButton(
                  key: ValueKey('service-see-all-${service.id}'),
                  onPressed: onSeeAll,
                  child: Text(
                    showAll ? 'Show less' : 'See all',
                    style: CustomerTypography.compact.copyWith(
                      color: CustomerColors.action,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!{'ELIGIBLE', 'CHECK_OPTION'}.contains(service.accessStatus))
            CatalogAccess(service: service),
          if (state.stage == DiscoveryStage.loading ||
              state.stage == DiscoveryStage.idle)
            const _OptionSkeleton()
          else if (state.stage == DiscoveryStage.failure || options.isEmpty)
            CatalogStatus(
              options: true,
              loading: false,
              failed: state.stage == DiscoveryStage.failure,
              empty: options.isEmpty,
              retry: retry,
            )
          else
            LayoutBuilder(
              builder: (context, bounds) {
                final large = MediaQuery.textScalerOf(context).scale(12) > 18;
                final columns = large || bounds.maxWidth < 300 ? 2 : 4;
                final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 14,
                  children: [
                    for (final option in (showAll ? options : options.take(4)))
                      SizedBox(
                        width: width,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            key: ValueKey('customer-option-${option.id}'),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onOption(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 5,
                              ),
                              child: Column(
                                children: [
                                  CatalogIcon(
                                    appearance: appearance,
                                    url: option.iconUrl,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    option.name,
                                    textAlign: TextAlign.center,
                                    style: CustomerTypography.compactStrong
                                        .copyWith(color: CustomerColors.text),
                                  ),
                                  if (option.access.accessStatus != 'ELIGIBLE')
                                    CatalogAccess(service: option.access),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OptionSkeleton extends StatelessWidget {
  const _OptionSkeleton();
  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('service-options-loading-skeleton'),
    children: [
      for (var i = 0; i < 3; i++)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5F1F1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F1F1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _ServicesLoadingSkeleton extends StatelessWidget {
  const _ServicesLoadingSkeleton();
  @override
  Widget build(BuildContext context) => const Column(
    key: ValueKey('services-loading-skeleton'),
    children: [
      _OptionSkeleton(),
      SizedBox(height: 24),
      _OptionSkeleton(),
      SizedBox(height: 24),
      _OptionSkeleton(),
    ],
  );
}
