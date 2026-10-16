import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/presentation/provider_tabs.dart';
import '../../home/presentation/provider_home_widgets.dart';
import '../../onboarding/requirements/domain/provider_onboarding_schema.dart';
import '../../onboarding/requirements/options/domain/provider_selected_option.dart';
import '../application/service_detail_controller.dart';
import 'service_catalog_visuals.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = serviceDetailControllerProvider(serviceTypeId);
    final state = ref.watch(provider);
    final result = state.asData?.value;
    return Theme(
      data: BThereTheme.authentication(),
      child: DecoratedBox(
        decoration: homeGradient,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: HomeNavigation(
            selectedIndex: 1,
            onSelect: (i) => context.go(ProviderTab.values[i].path),
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const HomeScale(child: HomeHeader()),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: state.isLoading
                        ? const Center(
                            child: BThereLoadingState(label: 'Loading service'),
                          )
                        : result is Success<ServiceDetailState>
                        ? SingleChildScrollView(
                            child: HomeScale(
                              child: _Overview(
                                value: result.value,
                                register: () =>
                                    context.push('/services/register'),
                                manage: (id) {
                                  final option = result.value.registered
                                      .where((option) => option.optionId == id)
                                      .firstOrNull;
                                  final inReview = [
                                    'PENDING',
                                    'REJECTED',
                                  ].contains(option?.verificationStatus);
                                  context.push(
                                    inReview
                                        ? AppRoutes.serviceStatus(serviceTypeId)
                                        : '/services/$serviceTypeId/register?optionId=$id',
                                  );
                                },
                                startOption: (id) {
                                  if (!result.value.selected.contains(id)) {
                                    ref.read(provider.notifier).toggle(id);
                                  }
                                  context.push(
                                    result.value.assignment == null &&
                                            result.value.registered.isEmpty &&
                                            !result.value.selected.contains(id)
                                        ? '/services/register'
                                        : '/services/$serviceTypeId/register?optionId=$id&details=1',
                                  );
                                },
                                back: () => context.go(AppRoutes.services),
                              ),
                            ),
                          )
                        : BThereStateView(
                            title: 'Unable to load service',
                            message: 'Please try again.',
                            action: BThereButton(
                              label: 'Retry',
                              onPressed: ref.read(provider.notifier).retry,
                            ),
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

class _Asset extends StatelessWidget {
  const _Asset(this.name);
  final String name;
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/service_detail/$name.svg');
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.value,
    required this.register,
    required this.manage,
    required this.startOption,
    required this.back,
  });
  final ServiceDetailState value;
  final VoidCallback register, back;
  final ValueChanged<int> manage;
  final ValueChanged<int> startOption;
  Text text(
    String value,
    double size, {
    bool bold = false,
    Color color = servicesInk,
  }) => Text(
    value,
    style: TextStyle(
      fontFamily: 'HomeLato',
      fontSize: size,
      height: 1.3,
      fontWeight: bold ? FontWeight.w900 : FontWeight.w400,
      color: color,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final registeredIds = value.registered.map((o) => o.optionId).toSet();
    final registered = value.schema.options
        .where((o) => registeredIds.contains(o.optionId))
        .toList();
    final available = value.schema.options
        .where((o) => !registeredIds.contains(o.optionId))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 191,
          child: Stack(
            children: [
              Positioned(
                left: 5,
                top: 0,
                child: IconButton(
                  tooltip: 'Back to services',
                  onPressed: back,
                  icon: const SizedBox(
                    width: 22,
                    height: 22,
                    child: _Asset('imgBack'),
                  ),
                ),
              ),
              Positioned(
                left: 26,
                top: 40,
                width: 54,
                height: 54,
                child: ServiceCatalogSymbol(service: value.service),
              ),
              Positioned(
                left: 26,
                top: 100,
                width: 238,
                child: text(value.service.name, 23, bold: true),
              ),
              Positioned(
                left: 26,
                top: 132,
                width: 238,
                child: text(
                  value.service.description ??
                      'Service details are available from the backend.',
                  13.5,
                  color: servicesMuted,
                ),
              ),
              if (value.service.usableCoverUri != null)
                Positioned(
                  left: 270,
                  top: 36,
                  width: 143,
                  height: 143,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      value.service.usableCoverUri.toString(),
                      fit: BoxFit.cover,
                      semanticLabel:
                          value.service.coverImage?.altText ??
                          value.service.name,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                )
              else
                Positioned(
                  left: 270,
                  top: 36,
                  width: 143,
                  height: 143,
                  child: Container(
                    decoration: BoxDecoration(
                      color: serviceVisualStyle(value.service).surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: ServiceCatalogSymbol(service: value.service),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (value.service.responsibilities.isNotEmpty ||
            [
              'caregiving',
              'caregiver',
            ].contains(value.service.name.trim().toLowerCase()))
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFFBFC),
                borderRadius: BorderRadius.circular(13),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned(
                    right: -13,
                    top: -8,
                    width: 111,
                    height: 150,
                    child: _Asset('imgBotanicalMotif'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        text('Key Responsibilities', 14.5, bold: true),
                        const SizedBox(height: 9),
                        for (final line
                            in value.service.responsibilities
                                .map(
                                  (item) => item.description == null
                                      ? item.title
                                      : '${item.title}: ${item.description}',
                                )
                                .toList())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.5),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: _Asset('imgCheckBadge'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: text(line, 11.1, color: servicesMuted),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (value.service.gallery.any((item) => item.usableUri != null))
          SizedBox(
            height: 112,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 10),
              scrollDirection: Axis.horizontal,
              itemCount: value.service.gallery.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final media = value.service.gallery[index];
                final uri = media.usableUri;
                return uri == null
                    ? const SizedBox.shrink()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          uri.toString(),
                          width: 150,
                          fit: BoxFit.cover,
                          semanticLabel: media.altText,
                          errorBuilder: (_, _, _) => const SizedBox(width: 150),
                        ),
                      );
              },
            ),
          ),
        if (registered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8FAFA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: text(
                          'Your Registered Sub-services',
                          14.5,
                          bold: true,
                        ),
                      ),
                      badge('${registered.length} registered', teal: true),
                    ],
                  ),
                  const SizedBox(height: 5),
                  for (final option in registered)
                    row(
                      option,
                      registered: value.registered.firstWhere(
                        (o) => o.optionId == option.optionId,
                      ),
                    ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text('Sub Services', 16, bold: true),
              const SizedBox(height: 7),
              text(
                'This service includes the following areas.',
                12,
                color: servicesMuted,
              ),
              const SizedBox(height: 7),
              for (final option in available) row(option),
              if (available.isEmpty)
                text(
                  'All available sub-services are registered.',
                  12,
                  color: servicesMuted,
                ),
              if (value.failure != null)
                text(value.failure!.message, 12, color: Colors.red),
            ],
          ),
        ),
        if (registered.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 38, 17, 26),
            child: SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFF00888B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: register,
                child: const Text(
                  'Register for this Service',
                  style: TextStyle(fontFamily: 'HomeLato', fontSize: 13.5),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 24),
      ],
    );
  }

  Widget badge(String label, {bool teal = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: teal ? const Color(0xFFDFF7F0) : const Color(0xFFFFF3DF),
      borderRadius: BorderRadius.circular(99),
    ),
    child: text(label, 10, color: teal ? homeTeal : const Color(0xFFBD6100)),
  );
  Widget symbol(String name) =>
      const Icon(Icons.volunteer_activism_outlined, color: homeTeal);
  Widget row(
    ProviderSchemaOption option, {
    ProviderSelectedOption? registered,
  }) {
    final incomplete =
        registered == null && value.selected.contains(option.optionId);
    final description = 'View details and registration requirements.';
    final status = registered == null
        ? null
        : registered.providerStatus == 'INACTIVE' ||
              registered.adminStatus == 'INACTIVE'
        ? 'Inactive'
        : registered.verificationStatus == 'REJECTED'
        ? 'Rejected'
        : registered.verificationStatus == 'APPROVED'
        ? 'Active'
        : registered.verificationStatus == 'PENDING'
        ? 'Pending review'
        : 'Status unavailable';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFEBEEF5), width: .8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: registered == null
              ? null
              : ValueKey('registered-option-${option.optionId}'),
          onTap: registered == null
              ? () => startOption(option.optionId)
              : () => manage(option.optionId),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: registered == null ? 61 : 49,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 9,
                vertical: registered == null ? 7 : 3.5,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: registered == null ? 46 : 42,
                    height: registered == null ? 46 : 42,
                    child: symbol(option.name),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        text(option.name, 10.8, bold: true),
                        const SizedBox(height: 3),
                        text(
                          registered == null
                              ? description
                              : 'Registered · Manage',
                          10.6,
                          color: registered == null ? servicesMuted : homeTeal,
                        ),
                      ],
                    ),
                  ),
                  if (status != null) badge(status, teal: status == 'Active'),
                  if (incomplete) badge('Incomplete'),
                  if (registered != null ||
                      value.assignment != null ||
                      incomplete)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 21,
                        height: 21,
                        child: _Asset(
                          registered == null
                              ? 'imgOpenSetting'
                              : 'imgDisclosure',
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
