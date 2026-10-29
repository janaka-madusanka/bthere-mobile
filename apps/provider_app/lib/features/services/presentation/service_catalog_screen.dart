import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../home/presentation/provider_home_widgets.dart';
import '../../onboarding/application/provider_completion_controller.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/application/provider_service_catalog_controller.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../application/service_providers.dart';
import '../application/service_setup_controller.dart';
import '../domain/provider_service_status.dart';
import 'service_catalog_card.dart';
import 'service_catalog_grid.dart';
import 'service_catalog_loading.dart';
import 'service_catalog_visuals.dart';
import 'service_featured_carousel.dart';

enum _ServiceFilter { all, registered, unregistered }

class ServiceCatalogScreen extends ConsumerStatefulWidget {
  const ServiceCatalogScreen({super.key});
  @override
  ConsumerState<ServiceCatalogScreen> createState() =>
      _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends ConsumerState<ServiceCatalogScreen> {
  bool _refreshing = false;
  final _search = TextEditingController();
  _ServiceFilter _filter = _ServiceFilter.all;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _busy =>
      _refreshing ||
      ref.read(providerServiceCatalogProvider).isLoading ||
      ref.read(providerAssignmentsProvider).isLoading ||
      ref.read(providerCompletionControllerProvider).isLoading;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _refreshing = true);
    ref.read(providerServiceCatalogProvider.notifier).reload();
    ref.invalidate(providerAssignmentsProvider);
    ref.read(providerCompletionControllerProvider.notifier).reload();
    try {
      await Future.wait([
        ref.read(providerServiceCatalogProvider.future),
        ref.read(providerAssignmentsProvider.future),
        ref.read(providerCompletionControllerProvider.future),
      ]);
    } catch (_) {
      // Each read retains its own error and retry presentation.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _showFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final filter = await showModalBottomSheet<_ServiceFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Filter services',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              for (final (value, label) in [
                (_ServiceFilter.all, 'All services'),
                (_ServiceFilter.registered, 'Registered services'),
                (_ServiceFilter.unregistered, 'Not registered'),
              ])
                ListTile(
                  title: Text(label),
                  trailing: value == _filter
                      ? const Icon(Icons.check, color: homeTeal)
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && filter != null) setState(() => _filter = filter);
  }

  ProviderServiceStatus? _status(
    ProviderServiceType service,
    List<ProviderServiceAssignment> owned,
    Result<ProviderCompletion>? progress,
  ) {
    final a = owned.where((a) => a.providerTypeId == service.id).firstOrNull;
    final c = progress is Success<ProviderCompletion>
        ? progress.value.services
              .where((c) => c.serviceTypeId == service.id)
              .firstOrNull
        : null;
    var status = productServiceStatus(
      a,
      c,
      progressKnown: progress is Success<ProviderCompletion>,
    );
    if (a != null && c != null) {
      final setup = ref
          .watch(serviceSetupControllerProvider(service.id))
          .asData
          ?.value;
      if (setup is Success<ServiceSetupData>) status = setup.value.status;
    }
    return status;
  }

  Widget _catalog(
    List<ProviderServiceType> types,
    List<ProviderServiceAssignment> owned,
    Result<ProviderCompletion>? progress,
    double scale,
  ) {
    final registeredIds = owned.map((a) => a.providerTypeId).toSet();
    final query = _search.text.trim().toLowerCase();
    final visible = types
        .where(
          (s) =>
              (query.isEmpty ||
                  s.name.toLowerCase().contains(query) ||
                  (s.description?.toLowerCase().contains(query) ?? false)) &&
              switch (_filter) {
                _ServiceFilter.all => true,
                _ServiceFilter.registered => registeredIds.contains(s.id),
                _ServiceFilter.unregistered => !registeredIds.contains(s.id),
              },
        )
        .toList();
    final registered = owned.isNotEmpty;
    final defaultView = query.isEmpty && _filter == _ServiceFilter.all;
    final remaining = registered && defaultView
        ? visible.where((s) => !registeredIds.contains(s.id)).toList()
        : visible;
    final featured = registered
        ? [
            for (final a in owned)
              types.where((s) => s.id == a.providerTypeId).firstOrNull ??
                  ProviderServiceType(
                    id: a.providerTypeId,
                    name: a.providerTypeName,
                    status: a.status,
                  ),
          ]
        : types.take(5).toList();
    final statuses = {
      for (final service in {...types, ...featured})
        service.id: _status(service, owned, progress),
    };
    void open(ProviderServiceType service) => context.go(
      [
            ProviderServiceStatus.pendingApproval,
            ProviderServiceStatus.rejected,
          ].contains(statuses[service.id])
          ? AppRoutes.serviceStatus(service.id)
          : AppRoutes.serviceDetail(service.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (featured.isNotEmpty &&
            query.isEmpty &&
            _filter == _ServiceFilter.all)
          if (registered)
            ServiceRegisteredGrid(
              services: featured,
              statuses: statuses,
              onSelect: open,
            )
          else
            ServiceFeaturedCarousel(
              key: ValueKey('featured-$registered'),
              services: featured,
              registered: false,
              onSelect: open,
            ),
        Padding(
          padding: EdgeInsets.fromLTRB(23 * scale, 0, 20 * scale, 20 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeading(remaining: registered && defaultView),
              if (types.isEmpty)
                const BThereStateView(
                  title: 'No services are available right now.',
                  message: 'Check back soon or refresh the service list.',
                )
              else if (visible.isEmpty)
                BThereStateView(
                  title: 'No matching services',
                  message: 'Try another search or filter.',
                  action: TextButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _filter = _ServiceFilter.all;
                    }),
                    child: const Text('Clear search and filters'),
                  ),
                )
              else if (remaining.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'All available services are registered.',
                    style: TextStyle(color: servicesMuted, fontSize: 12),
                  ),
                )
              else
                ServiceCatalogGrid(
                  children: [
                    for (final service in remaining)
                      ServiceCatalogCard(
                        service: service,
                        status: statuses[service.id],
                        onTap: () => open(service),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading({bool remaining = false}) => SizedBox(
    height: 38,
    child: Row(
      children: [
        const ServicesAsset('imgNavigationSymbol3', size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              remaining ? 'Remaining Services' : 'All Services',
              style: TextStyle(
                fontSize:
                    15.5 *
                    (MediaQuery.sizeOf(context).width / 430).clamp(.65, 1.0),
                fontWeight: FontWeight.w700,
                color: servicesInk,
              ),
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          label: _busy ? 'Refreshing services' : null,
          child: SizedBox(
            width: 40,
            height: 38,
            child: IconButton(
              key: const ValueKey('refresh-services'),
              tooltip: 'Refresh services',
              onPressed: _busy ? null : _refresh,
              icon: _busy
                  ? const BThereLoadingIndicator(size: 18)
                  : const Icon(Icons.refresh, size: 19, color: homeTeal),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _intro(double scale) => Padding(
    padding: EdgeInsets.fromLTRB(
      24 * scale,
      23 * scale,
      18 * scale,
      24 * scale,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SERVICES',
          style: TextStyle(
            fontSize: 10 * scale,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: servicesMuted,
          ),
        ),
        const SizedBox(height: 7),
        Semantics(
          header: true,
          child: Text(
            'Explore Services',
            style: TextStyle(
              fontSize: 26 * scale,
              height: 32 / 26,
              fontWeight: FontWeight.w800,
              color: servicesInk,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Discover the services you can offer and make a difference.',
          style: TextStyle(
            fontSize: 13 * scale,
            height: 18 / 13,
            color: servicesMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 39 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE1E5EE), width: .7),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              const ServicesAsset('imgNavigationSymbol2', size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  key: const ValueKey('search-services'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontFamily: 'HomeInter',
                    fontSize: 13 * scale,
                    height: 1.2,
                    letterSpacing: 0,
                    color: servicesInk,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search services',
                    hintStyle: TextStyle(color: Color(0xFFACB5CA)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_search.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => setState(_search.clear),
                  icon: const Icon(Icons.close, size: 18),
                ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFE1E5EE), width: .7),
                  ),
                ),
                child: IconButton(
                  key: const ValueKey('filter-services'),
                  tooltip: 'Filter services',
                  onPressed: _showFilters,
                  icon: const ServicesAsset('imgSlidersHorizontal', size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: _filter == _ServiceFilter.all
                        ? Colors.transparent
                        : const Color(0xFFDEFAF5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(providerServiceCatalogProvider);
    final assignments = ref.watch(providerAssignmentsProvider);
    final completion = ref.watch(providerCompletionControllerProvider);
    final types = catalog.asData?.value, owned = assignments.asData?.value;
    final progress = completion.asData?.value;
    final scale = (MediaQuery.sizeOf(context).width / 430).clamp(.74, 1.0);
    Widget content;
    if (catalog.isLoading || assignments.isLoading) {
      content = Column(
        children: [
          _sectionHeading(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: ServiceCatalogLoading(),
          ),
        ],
      );
    } else if (types is! Success<List<ProviderServiceType>> ||
        owned is! Success<List<ProviderServiceAssignment>>) {
      content = Column(
        children: [
          _sectionHeading(),
          BThereStateView(
            title: 'Unable to load services',
            message: 'Please try again.',
            action: BThereButton(
              label: 'Retry',
              onPressed: _busy ? null : _refresh,
            ),
          ),
        ],
      );
    } else {
      content = _catalog(types.value, owned.value, progress, scale);
    }
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'HomeInter',
          bodyColor: servicesInk,
          displayColor: servicesInk,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'HomeInter',
          fontSize: 14,
          color: servicesInk,
          letterSpacing: 0,
        ),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: DecoratedBox(
            decoration: homeGradient,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const HomeScale(child: HomeHeader()),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21 * scale),
                      child: ColoredBox(
                        color: Colors.white,
                        child: LayoutBuilder(
                          builder: (context, bounds) => RefreshIndicator(
                            onRefresh: _refresh,
                            child: SingleChildScrollView(
                              key: const PageStorageKey('services-scroll'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: bounds.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _intro(scale),
                                    if (completion.isLoading)
                                      const BThereLoadingState(
                                        label: 'Loading service progress',
                                        compact: true,
                                      )
                                    else if (progress
                                            is Failure<ProviderCompletion> ||
                                        completion.hasError)
                                      TextButton(
                                        onPressed: () => ref
                                            .read(
                                              providerCompletionControllerProvider
                                                  .notifier,
                                            )
                                            .reload(),
                                        child: const Text(
                                          'Service progress unavailable · Retry',
                                        ),
                                      ),
                                    content,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
