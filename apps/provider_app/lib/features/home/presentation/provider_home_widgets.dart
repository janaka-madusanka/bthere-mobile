import 'package:bthere_common/bthere_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../onboarding/domain/provider_completion.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../onboarding/services/domain/provider_service_type.dart';
import '../../onboarding/requirements/options/domain/provider_selected_option.dart';
import '../../services/domain/provider_service_status.dart';
import '../../services/application/service_providers.dart';
import '../../services/presentation/service_catalog_visuals.dart';
import '../../onboarding/application/provider_completion_controller.dart';

const homeInk = Color(0xFF070C30),
    homeMuted = Color(0xFF75819B),
    homeTeal = Color(0xFF008B91);

// Reserve space for enlarged text without changing normal-size Figma geometry.
double _textGrowth(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(0.0, 0.3);
const homeGradient = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, -.2),
    radius: 1.1,
    colors: [Color(0xFF008F93), Color(0xFF007277), Color(0xFF00555B)],
  ),
);

/// Coordinates remain in the source frame's 430-point grid at every width.
/// Height remains intrinsic, allowing scrolling and larger accessibility text.
class HomeScale extends StatelessWidget {
  const HomeScale({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.fitWidth,
    alignment: Alignment.topCenter,
    child: SizedBox(width: 430, child: child),
  );
}

class HomeAsset extends StatelessWidget {
  const HomeAsset(this.name, {super.key, this.width, this.height});
  final String name;
  final double? width, height;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/home/$name.svg',
    width: width,
    height: height,
    fit: BoxFit.contain,
  );
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: Stack(
      children: [
        const Positioned(
          left: -143,
          top: -190,
          width: 355,
          height: 279,
          child: HomeAsset('new_imgBackgroundGlow'),
        ),
        const Positioned(
          left: 25.8,
          top: 8,
          width: 84,
          height: 31,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 25.27,
                height: 31,
                child: HomeAsset('new_imgGroup'),
              ),
              Positioned(
                right: 0,
                top: 13.16,
                width: 54.57,
                height: 15.35,
                child: HomeAsset('new_imgGroup1'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 326,
          top: 0,
          child: _headerAction(
            context,
            'Requests',
            'new_imgNavigationSymbol1',
            AppRoutes.requests,
            25,
          ),
        ),
        Positioned(
          left: 372,
          top: 0,
          child: _headerAction(
            context,
            'Profile',
            'new_imgNavigationSymbol',
            AppRoutes.account,
            30,
          ),
        ),
      ],
    ),
  );
  Widget _headerAction(
    BuildContext context,
    String label,
    String asset,
    String route,
    double size,
  ) => Tooltip(
    message: label,
    child: SizedBox(
      width: 47,
      height: 47,
      child: Center(
        child: Material(
          color: const Color(0x70008D92),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go(route),
            child: SizedBox(
              width: 33,
              height: 33,
              child: Center(
                child: HomeAsset(asset, width: size, height: size),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeWelcome extends StatelessWidget {
  const HomeWelcome({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 284 + 220 * _textGrowth(context),
    child: Stack(
      children: [
        const Positioned(
          left: 286,
          top: -8,
          width: 160,
          height: 205,
          child: HomeAsset('new_imgBotanicalIllustration'),
        ),
        const Positioned(
          left: 27,
          top: 34,
          child: Text(
            'WELCOME TO BTHERE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: .8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C7893),
            ),
          ),
        ),
        Positioned(
          left: 27,
          top: 54 + 10 * _textGrowth(context),
          child: const Text(
            'Your skills\ncreate better days',
            style: TextStyle(
              fontSize: 27.5,
              height: 1.1,
              letterSpacing: -.9625,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          left: 27,
          top: 120 + 80 * _textGrowth(context),
          child: const Text(
            'Find opportunities, help people,\nand grow your income.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.3,
              letterSpacing: -.29,
              color: homeMuted,
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 175 + 120 * _textGrowth(context),
          width: 395,
          height: 96 + 100 * _textGrowth(context),
          child: Material(
            borderRadius: BorderRadius.circular(13),
            color: const Color(0xFFF0FAFA),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => context.go('${AppRoutes.services}/register'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 0, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDDF8F7),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const HomeAsset(
                            'new_imgIcon5',
                            width: 38,
                            height: 38,
                          ),
                          Positioned(
                            left: 36,
                            top: 32,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: homeTeal,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Register your first service',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.435,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose what you offer and start\nreceiving opportunities.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              letterSpacing: -.36,
                              color: homeMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: homeTeal,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/home/registration_arrow.png',
                          width: 20,
                          height: 20,
                        ),
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
  );
}

class HomeHeading extends StatelessWidget {
  const HomeHeading(
    this.title, {
    super.key,
    required this.onTap,
    this.action = 'View all',
    this.registered = false,
  });
  final String title, action;
  final VoidCallback onTap;
  final bool registered;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: (registered ? 25 : 22) + 40 * _textGrowth(context),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: registered ? 14.7 : 17,
              height: registered ? 1.2 : 1.3,
              fontWeight: FontWeight.w800,
              letterSpacing: registered ? 0 : -.51,
            ),
          ),
        ),
        Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: registered ? 10 : 10.5,
                    fontWeight: FontWeight.w600,
                    color: homeTeal,
                    letterSpacing: -.315,
                  ),
                ),
                const SizedBox(width: 5),
                HomeAsset(
                  registered ? 'existing_imgSymbol3' : 'new_imgArrowRight',
                  width: registered ? 14 : 13,
                  height: registered ? 14 : 13,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, this.username, required this.now});
  final String? username;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final greeting = now.hour < 12
        ? 'Good morning,'
        : now.hour < 18
        ? 'Good afternoon,'
        : 'Good evening,';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 199 + 102 * _textGrowth(context)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 15, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 11, right: 9),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: 42 + 42 * _textGrowth(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              fontSize: 11.4,
                              height: 1.2,
                              color: homeMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${username ?? 'Your dashboard'} 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21.5,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 31,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE6EAF2),
                          width: .6,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const HomeAsset(
                            'existing_imgSymbol',
                            width: 17,
                            height: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF616C90),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeMetric(
                    'Opportunities\nReceived',
                    'existing_imgSymbol1',
                    Color(0xFFF2FCFA),
                    Color(0xFFDFFFF5),
                  ),
                  SizedBox(width: 8),
                  HomeMetric(
                    'In Progress',
                    'existing_imgSymbol2',
                    Color(0xFFF1FAFF),
                    Color(0xFFDDF2FF),
                  ),
                  SizedBox(width: 8),
                  HomeMetric(
                    'Completed',
                    'existing_imgMetricSymbol',
                    Color(0xFFFFF9F1),
                    null,
                  ),
                  SizedBox(width: 8),
                  HomeMetric(
                    'Happy Clients',
                    'existing_imgHappyClientsSymbol',
                    Color(0xFFFFF3F8),
                    Color(0xFFFFE0EA),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeMetric extends StatelessWidget {
  const HomeMetric(
    this.label,
    this.asset,
    this.surface,
    this.circle, {
    super.key,
  });
  final String label, asset;
  final Color surface;
  final Color? circle;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Tooltip(
      message: '$label: statistics unavailable',
      child: Container(
        constraints: BoxConstraints(minHeight: 103 + 60 * _textGrowth(context)),
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
              child: Center(
                child: HomeAsset(
                  asset,
                  width: circle == null ? 39 : 23,
                  height: circle == null ? 39 : 23,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '—',
              style: TextStyle(
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.3,
                height: 1.2,
                color: homeMuted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final homeServiceOptionsProvider = FutureProvider.autoDispose
    .family<Result<List<ProviderSelectedOption>>, int>(
      (ref, id) async {
        // Invalidate when the assignment list refreshes after service setup changes.
        ref.watch(providerAssignmentsProvider);
        try {
          return await ref
              .watch(providerOptionsRepositoryProvider)
              .loadSelections(id);
        } catch (_) {
          return const Failure(
            AppFailure(message: 'Unable to load sub services.'),
          );
        }
      },
      dependencies: [
        providerAssignmentsProvider,
        providerOptionsRepositoryProvider,
      ],
    );

class HomeRegisteredService extends ConsumerWidget {
  const HomeRegisteredService({
    super.key,
    required this.assignment,
    this.completion,
  });
  final ProviderServiceAssignment assignment;
  final ProviderServiceCompletion? completion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref
        .watch(homeServiceOptionsProvider(assignment.assignmentId))
        .asData
        ?.value;
    final options = result is Success<List<ProviderSelectedOption>>
        ? result.value
        : null;
    final status = productServiceStatus(assignment, completion);
    final active =
        status == ProviderServiceStatus.approved &&
        assignment.providerStatus == 'ACTIVE' &&
        assignment.adminStatus == 'ACTIVE';
    final label = active ? 'Active' : status?.label ?? 'Status unavailable';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE6EAF2), width: .6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await context.push(AppRoutes.serviceSetup(assignment.providerTypeId));
          if (context.mounted) {
            ref.invalidate(providerAssignmentsProvider);
            ref.invalidate(providerCompletionControllerProvider);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 8, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HomeServicePhoto(name: assignment.providerTypeName),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assignment.providerTypeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    options == null
                                        ? 'Sub services unavailable'
                                        : '${options.length} sub service${options.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 8.7,
                                      height: 1.2,
                                      color: homeMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              height: 19,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFE4FBF4)
                                    : const Color(0xFFFFF6D8),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                children: [
                                  if (active) ...[
                                    const HomeAsset(
                                      'existing_imgActiveIndicator',
                                      width: 5,
                                      height: 5,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 8.2,
                                      height: 1.2,
                                      color: active
                                          ? const Color(0xFF009D78)
                                          : const Color(0xFF735A0C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const HomeAsset(
                              'existing_imgSymbol4',
                              width: 13,
                              height: 13,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (options != null)
                          Row(
                            children: [
                              for (final option in options.take(3))
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: _chip(option.name),
                                  ),
                                ),
                              if (options.length > 3)
                                _chip('+${options.length - 3}'),
                            ],
                          ),
                      ],
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

  Widget _chip(String text) => Container(
    height: 18,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F8),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 7.7, height: 1.2, color: homeMuted),
      ),
    ),
  );
}

/// Only the three photograph slots from the supplied Figma export are visible.
class HomeServicePhoto extends StatelessWidget {
  const HomeServicePhoto({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final visual = serviceVisualStyle(
      ProviderServiceType(
        id: name.hashCode.abs() + 1,
        name: name,
        status: 'ACTIVE',
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 84,
        height: 61,
        child: ColoredBox(
          color: visual.surface,
          child: Center(
            child: Icon(
              Icons.miscellaneous_services,
              color: const Color(0xFF008B91),
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

// Static category taxonomy and presentation assets from each Figma frame.
// Navigation resolves backend IDs by name, never by a fabricated service ID.
typedef _Category = (String, String, Color, Color?, double);
const _newCategories = <_Category>[
  ('Caregiving', 'new_imgCategorySymbol', Color(0xFFF0FCFA), null, 44),
  ('Home Services', 'new_imgIcon6', Color(0xFFEFF9FE), Color(0xFFDEF5FF), 26),
  ('Pet Care', 'new_imgIcon7', Color(0xFFFFF9F4), Color(0xFFFFF0E4), 26),
  ('Childcare', 'new_imgCategorySymbol1', Color(0xFFFFF6F9), null, 44),
  ('Handyman', 'new_imgIcon8', Color(0xFFF9F5FF), Color(0xFFF0E8FF), 26),
  ('Vehicle Services', 'new_imgCategorySymbol2', Color(0xFFFFFBF0), null, 44),
  (
    'Errands & Delivery',
    'new_imgIcon9',
    Color(0xFFEEFCFE),
    Color(0xFFD7FAFD),
    26,
  ),
  (
    'Wellness & Lifestyle',
    'new_imgIcon10',
    Color(0xFFF0FCF3),
    Color(0xFFDDFFE5),
    26,
  ),
];
const _registeredCategories = <_Category>[
  (
    'Home Services',
    'existing_imgSymbol5',
    Color(0xFFF1FAFF),
    Color(0xFFDFF3FF),
    25,
  ),
  (
    'Childcare',
    'existing_imgChildcareSymbol',
    Color(0xFFFFF3F7),
    Color(0xFFFFE1EB),
    25,
  ),
  (
    'Household Support',
    'existing_imgSprayCan',
    Color(0xFFF0FCF9),
    Color(0xFFD7FBF6),
    25,
  ),
  (
    'Mobility Assistance',
    'existing_imgMobilityAssistanceSymbol',
    Color(0xFFFFF9F1),
    Color(0xFFFFF0DC),
    25,
  ),
  (
    'Vehicle Services',
    'existing_imgCarFront',
    Color(0xFFFFFBEB),
    Color(0xFFFFF4CD),
    25,
  ),
  (
    'Errands & Delivery',
    'existing_imgSymbol6',
    Color(0xFFEEFCFE),
    Color(0xFFD7FAFD),
    25,
  ),
  ('Handyman', 'existing_imgSymbol7', Color(0xFFF8F1FF), Color(0xFFF0E0FF), 25),
  (
    'Wellness & Lifestyle',
    'existing_imgSymbol8',
    Color(0xFFF0FCF3),
    Color(0xFFDDFBE7),
    25,
  ),
];

class HomeCategories extends StatelessWidget {
  const HomeCategories({
    super.key,
    required this.registered,
    required this.services,
  });
  final bool registered;
  final List<ProviderServiceType> services;
  @override
  Widget build(BuildContext context) {
    final categories = registered ? _registeredCategories : _newCategories;
    final gap = registered ? 8.0 : 11.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        registered ? 2 : 8,
        registered ? 16 : 17,
        registered ? 8 : 0,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: registered ? 0 : 5,
              right: registered ? 0 : 4,
            ),
            child: HomeHeading(
              registered ? 'Popular Services' : 'Popular services',
              registered: registered,
              onTap: () => context.go(AppRoutes.services),
            ),
          ),
          SizedBox(height: registered ? 8 : 12),
          for (final row in [categories.take(4), categories.skip(4)]) ...[
            Row(
              children: [
                for (final (index, category) in row.indexed) ...[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(
                    child: Material(
                      color: category.$3,
                      borderRadius: BorderRadius.circular(registered ? 10 : 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          final service = services
                              .where(
                                (s) =>
                                    s.name.toLowerCase() ==
                                    category.$1.toLowerCase(),
                              )
                              .firstOrNull;
                          if (service == null) {
                            context.go(AppRoutes.services);
                          } else {
                            context.push('/services/${service.id}');
                          }
                        },
                        child: SizedBox(
                          height:
                              (registered ? 66 : 82) +
                              50 * _textGrowth(context),
                          child: Column(
                            children: [
                              SizedBox(height: registered ? 5 : 9),
                              Container(
                                width: registered ? 37 : 44,
                                height: registered ? 37 : 44,
                                decoration: BoxDecoration(
                                  color: category.$4,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: HomeAsset(
                                    category.$2,
                                    width: category.$5,
                                    height: category.$5,
                                  ),
                                ),
                              ),
                              SizedBox(height: registered ? 4 : 5),
                              Text(
                                category.$1,
                                maxLines: _textGrowth(context) > 0 ? 2 : 1,
                                style: TextStyle(
                                  fontSize: registered
                                      ? 8.3
                                      : category.$1.length > 16
                                      ? 9
                                      : 9.7,
                                  height: registered ? 1.2 : 1.3,
                                  letterSpacing: registered ? 0 : -.291,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (row.first == categories.first)
              SizedBox(height: registered ? 8 : 9),
          ],
        ],
      ),
    );
  }
}

class HomeNavigation extends StatelessWidget {
  const HomeNavigation({
    super.key,
    required this.onSelect,
    this.selectedIndex = 0,
  });
  final void Function(int) onSelect;
  final int selectedIndex;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: homeGradient,
    child: SafeArea(
      top: false,
      child: HomeScale(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(21, 10, 21, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final item in [
                (0, 'Home', 'new_imgIcon'),
                (2, 'Opportunities', 'new_imgIcon1'),
                (1, 'Services', 'new_imgIcon2'),
                (3, 'Messages', 'new_imgIcon3'),
                (4, 'Profile', 'new_imgIcon4'),
              ])
                Semantics(
                  key: ValueKey('provider-tab-${item.$1}'),
                  button: true,
                  selected: item.$1 == selectedIndex,
                  label:
                      '${item.$2}\nTab ${const [0, 2, 1, 3, 4].indexOf(item.$1) + 1} of 5',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onSelect(item.$1),
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 64,
                        maxWidth: 64,
                        minHeight: 48,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 49,
                            height: 33,
                            decoration: BoxDecoration(
                              color: item.$1 == selectedIndex
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Center(
                              child: item.$1 == selectedIndex && item.$1 != 0
                                  ? ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        homeTeal,
                                        BlendMode.srcIn,
                                      ),
                                      child: HomeAsset(
                                        item.$3,
                                        width: 25,
                                        height: 25,
                                      ),
                                    )
                                  : item.$1 == 0 && selectedIndex != 0
                                  ? const ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Color(0xFFB9DFE0),
                                        BlendMode.srcIn,
                                      ),
                                      child: HomeAsset(
                                        'new_imgIcon',
                                        width: 25,
                                        height: 25,
                                      ),
                                    )
                                  : HomeAsset(item.$3, width: 25, height: 25),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'HomeInter',
                              fontSize: 9.5,
                              height: 1.3,
                              letterSpacing: -.285,
                              color: item.$1 == selectedIndex
                                  ? Colors.white
                                  : const Color(0xFFB9DFE0),
                            ),
                          ),
                        ],
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

class HomeCommunity extends StatelessWidget {
  const HomeCommunity({super.key});
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: 104 + 60 * _textGrowth(context)),
    decoration: BoxDecoration(
      color: const Color(0xFFF2FAFA),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 14),
      child: Row(
        children: [
          for (final (index, item) in [
            ('Service providers', 'new_imgIcon11', Color(0xFFDDFBF6)),
            ('People supported', 'new_imgIcon12', Color(0xFFFFE7EE)),
            (
              'Service categories',
              'new_imgStatisticSymbol',
              Colors.transparent,
            ),
          ].indexed) ...[
            if (index > 0)
              const SizedBox(
                height: 66,
                child: VerticalDivider(
                  width: .6,
                  thickness: .6,
                  color: Color(0xFFDFECEF),
                ),
              ),
            Expanded(
              child: Tooltip(
                message: '${item.$1}: statistics unavailable',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 37,
                      height: 37,
                      decoration: BoxDecoration(
                        color: item.$3,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: HomeAsset(
                          item.$2,
                          width: index == 2 ? 37 : 20,
                          height: index == 2 ? 37 : 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '—',
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.51,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.3,
                        color: homeMuted,
                        letterSpacing: -.285,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class HomeResources extends StatelessWidget {
  const HomeResources({super.key, required this.registered});
  final bool registered;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      registered ? 18 : 21,
      registered ? 2 : 13,
      registered ? 16 : 20,
      registered ? 11 : 15,
    ),
    child: Column(
      children: [
        HomeHeading(
          registered ? 'Helpful Resources' : 'Helpful resources',
          registered: registered,
          onTap: () => _open(context, 'Helpful resources'),
        ),
        SizedBox(height: registered ? 8 : 10),
        Row(
          children: [
            for (final (index, item) in [
              (
                'Provider\nguide',
                registered ? 'existing_imgBookOpen' : 'new_imgBookOpen',
              ),
              (
                'Safety tips',
                registered ? 'existing_imgSymbol10' : 'new_imgIcon13',
              ),
              ('FAQs', registered ? 'existing_imgSymbol11' : 'new_imgIcon14'),
            ].indexed) ...[
              if (index > 0) SizedBox(width: registered ? 9 : 11),
              Expanded(
                child: Material(
                  color: registered ? Colors.white : const Color(0xFFFCFDFE),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(registered ? 10 : 12),
                    side: BorderSide(
                      color: registered
                          ? const Color(0xFFE6EAF2)
                          : const Color(0xFFE8EEF3),
                      width: registered ? .6 : .7,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open(context, item.$1.replaceAll('\n', ' ')),
                    child: SizedBox(
                      height:
                          (registered ? 49 : 60) + 40 * _textGrowth(context),
                      child: Padding(
                        padding: registered
                            ? const EdgeInsets.symmetric(horizontal: 6)
                            : const EdgeInsets.fromLTRB(8, 0, 7, 0),
                        child: Row(
                          children: [
                            Container(
                              width: registered ? 36 : 35,
                              height: registered ? 36 : 35,
                              decoration: BoxDecoration(
                                color: index == 2
                                    ? (registered
                                          ? const Color(0xFFEFF5F6)
                                          : const Color(0xFFEAF2F4))
                                    : (registered
                                          ? const Color(0xFFEAF7FF)
                                          : const Color(0xFFE5F5FF)),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: HomeAsset(
                                  item.$2,
                                  width: registered ? 24 : 22,
                                  height: registered ? 24 : 22,
                                ),
                              ),
                            ),
                            SizedBox(width: registered ? 8 : 7),
                            Expanded(
                              child: Text(
                                item.$1,
                                style: TextStyle(
                                  fontSize: registered ? 9 : 8.8,
                                  height: registered ? 1.2 : 1.3,
                                  fontWeight: registered
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  letterSpacing: registered ? 0 : -.264,
                                ),
                              ),
                            ),
                            HomeAsset(
                              registered
                                  ? 'existing_imgSymbol9'
                                  : 'new_imgChevronRight',
                              width: registered ? 12 : 11,
                              height: registered ? 12 : 11,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
  void _open(BuildContext context, String title) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text('Resource content is not available yet.'),
          ],
        ),
      ),
    ),
  );
}
