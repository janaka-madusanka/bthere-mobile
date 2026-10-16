import 'dart:math' as math;

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../home/presentation/provider_home_widgets.dart';
import '../../onboarding/profile/data/provider_profile_reader.dart';
import '../../onboarding/profile/domain/provider_profile_input.dart';
import '../../onboarding/profile/presentation/provider_profile_screen.dart';
import '../../onboarding/services/domain/provider_service_assignment.dart';
import '../../services/application/service_providers.dart';
import '../../services/data/registration_repository.dart';
import '../../services/documents/document_models.dart';
import '../../services/documents/documents_controller.dart';
import '../../services/documents/documents_screen.dart';
import '../application/provider_account_controller.dart';
import '../application/provider_profile_overview.dart';

part 'provider_profile_panels.dart';
part 'provider_profile_editors.dart';
part 'provider_profile_widgets.dart';

const _ink = Color(0xFF090744), _muted = Color(0xFF7E89AA);

class ProviderAccountScreen extends ConsumerStatefulWidget {
  const ProviderAccountScreen({super.key});
  @override
  ConsumerState<ProviderAccountScreen> createState() =>
      _ProviderAccountScreenState();
}

class _ProviderAccountScreenState extends ConsumerState<ProviderAccountScreen> {
  bool _savingAvailability = false;

  Future<void> _refresh() async {
    if (_savingAvailability || ref.read(providerSignOutProvider).busy) return;
    ref.invalidate(providerAccountProvider);
    ref.invalidate(providerProfileDetailsProvider);
    ref.invalidate(providerAssignmentsProvider);
    ref.invalidate(profileDocumentsProvider);
    ref.invalidate(profileDocumentRequirementsProvider);
    ref.invalidate(profileSupplementProvider);
    try {
      await Future.wait([
        ref.read(providerAccountProvider.future),
        ref.read(providerProfileDetailsProvider.future),
      ]);
    } catch (_) {
      // Each section renders its own safe error and retry state.
    }
  }

  Future<void> _edit(Map<String, dynamic> profile) async {
    final container = ProviderScope.containerOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => UncontrolledProviderScope(
          container: container,
          child: ProviderProfileScreen(
            initialProfile: profile,
            onBack: () => Navigator.pop(routeContext),
            onSaved: () {
              ref.invalidate(providerProfileDetailsProvider);
              Navigator.pop(routeContext);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _availability(Map<String, dynamic> p, bool available) async {
    if (_savingAvailability) return;
    setState(() => _savingAvailability = true);
    try {
      final input = ProviderProfileInput(
        marketId: p['marketId'] as int,
        firstName: p['firstName'] as String,
        lastName: p['lastName'] as String,
        dateOfBirth: DateTime.parse(p['dateOfBirth'] as String),
        gender:
            ProviderGender.tryParse(p['gender']) ??
            (throw const FormatException()),
        availabilityStatus: available
            ? ProviderAvailability.available
            : ProviderAvailability.unavailable,
        bio: p['bio'] as String?,
        nicNumber: p['nicNumber'] as String?,
        passportNumber: p['passportNumber'] as String?,
        profilePhoto: p['profilePhoto'] as String?,
      );
      final result = await ref
          .read(providerProfileRepositoryProvider)
          .updateProfile(input);
      if (result is! Success<void>) throw const FormatException();
      ref.invalidate(providerProfileDetailsProvider);
      await ref.read(providerProfileDetailsProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update availability. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAvailability = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your provider account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(providerSignOutProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(providerAccountProvider);
    final profile = ref.watch(providerProfileDetailsProvider);
    final result = profile.asData?.value;
    final p =
        result is Success<Map<String, dynamic>> &&
            result.value['firstName'] is String &&
            result.value['lastName'] is String
        ? result.value
        : null;
    final supplementResult = ref.watch(profileSupplementProvider).asData?.value;
    final supplement = supplementResult is Success<ProfileSupplement>
        ? supplementResult.value
        : null;
    final assignments = ref.watch(providerAssignmentsProvider).asData?.value;
    final services = assignments is Success<List<ProviderServiceAssignment>>
        ? assignments.value
        : null;
    final signOut = ref.watch(providerSignOutProvider);
    final busy = signOut.busy || _savingAvailability;
    final name = p == null
        ? account.asData?.value?.username ?? 'Provider account'
        : '${p['firstName']} ${p['lastName']}';
    final rating = p?['averageRating'];
    final reviews = p?['totalRatings'];
    final available = p?['availabilityStatus'] == 'AVAILABLE';
    final verified = p?['verificationStatus'] == 'APPROVED';
    final normalText = MediaQuery.textScalerOf(context).scale(12) <= 15.6;

    return PopScope(
      canPop: !signOut.busy,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: DecoratedBox(
          decoration: homeGradient,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                HomeScale(
                  child: _ProfileHeader(onAccount: () => _support(true)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Material(
                      color: Colors.white,
                      child: LayoutBuilder(
                        builder: (context, viewport) {
                          final width = normalText
                              ? 430.0
                              : math.min(viewport.maxWidth, 600.0);
                          final content = SizedBox(
                            width: width,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: normalText
                                    ? math.max(
                                        737,
                                        viewport.maxHeight *
                                            430 /
                                            viewport.maxWidth,
                                      )
                                    : viewport.maxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  22,
                                  24,
                                  58,
                                ),
                                child: DefaultTextStyle(
                                  style: const TextStyle(
                                    fontFamily: 'HomeInter',
                                    color: _ink,
                                    fontSize: 10,
                                    height: 1.22,
                                    letterSpacing: 0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _ProfileIdentity(
                                        name: name,
                                        photo: p?['profilePhoto'],
                                        rating: rating,
                                        reviews: reviews,
                                        verified: verified,
                                        verification: p?['verificationStatus'],
                                        onEdit: p == null || busy
                                            ? null
                                            : () => _edit(p),
                                      ),
                                      if (profile.isLoading ||
                                          account.isLoading)
                                        const LinearProgressIndicator(),
                                      if (!profile.isLoading && p == null)
                                        _Retry(
                                          label: 'Unable to load provider details.',
                                          onRetry: _refresh,
                                        ),
                                      if (account.hasError)
                                        _Retry(
                                          label:
                                              'Unable to load account details',
                                          onRetry: _refresh,
                                        ),
                                      const SizedBox(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Metric(
                                              asset: 'imgBriefcaseMedical',
                                              value:
                                                  services?.length.toString() ??
                                                  '?',
                                              label: 'Services',
                                              caption: 'Registered',
                                              color: const Color(0xFFEFFBFA),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _Metric(
                                              asset: 'imgMetricIcon',
                                              value:
                                                  supplement?.completedBookings
                                                      ?.toString() ??
                                                  '?',
                                              label: 'Bookings',
                                              caption: 'Completed',
                                              color: const Color(0xFFF8F3FD),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _Metric(
                                              asset: 'imgIconBackground',
                                              value: rating is num
                                                  ? rating.toStringAsFixed(1)
                                                  : '?',
                                              label: 'Rating',
                                              caption: reviews is num
                                                  ? 'Based on $reviews reviews'
                                                  : 'No reviews',
                                              color: const Color(0xFFFFFBF2),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF9F5),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: available
                                                                  ? const Color(
                                                                      0xFF24C354,
                                                                    )
                                                                  : _muted,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          available
                                                              ? 'Available for Work'
                                                              : 'Unavailable for Work',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    available
                                                        ? 'You can receive booking requests'
                                                        : 'Booking requests are paused',
                                                    style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 10.8,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              height: 46,
                                              width: 47,
                                              child: FittedBox(
                                                fit: BoxFit.contain,
                                                child: Switch(
                                                  value: available,
                                                  onChanged: busy || p == null
                                                      ? null
                                                      : (v) =>
                                                            _availability(p, v),
                                                  activeTrackColor: homeTeal,
                                                  activeThumbColor:
                                                      Colors.white,
                                                  trackOutlineColor:
                                                      const WidgetStatePropertyAll(
                                                        Colors.transparent,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      const _Heading('My Account'),
                                      _ProfileSection(
                                        asset: 'imgSetting',
                                        title: 'Personal Information',
                                        subtitle:
                                            'Update your personal details',
                                        expandedSubtitle:
                                            'Your personal details',
                                        onEdit: busy || p == null
                                            ? null
                                            : () => _edit(p),
                                        body: () => _PersonalPanel(
                                          name: name,
                                          email: account.asData?.value?.email,
                                          phone: account
                                              .asData
                                              ?.value
                                              ?.phoneNumber,
                                          profile: p,
                                          supplement: supplement,
                                        ),
                                      ),
                                      _ProfileSection(
                                        asset: 'imgFileText',
                                        title: 'Documents & Verification',
                                        subtitle: 'Manage your documents and verification status',
                                        onEdit: busy
                                            ? null
                                            : () => _documentManager(),
                                        body: () => _DocumentsPanel(
                                          onEdit: busy ? null : _editDocument,
                                        ),
                                      ),
                                      _ProfileSection(
                                        asset: 'imgSetting1',
                                        title: 'Payouts',
                                        subtitle: 'Manage your payment details',
                                        onEdit: busy
                                            ? null
                                            : () => _editGlobal(
                                                'Payouts',
                                                supplement,
                                              ),
                                        body: () => _PayoutPanel(
                                          value: supplement?.payout,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const _Heading('Support'),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final tiles = [
                                            _SupportTile(
                                              title: 'Help & Support',
                                              subtitle: 'FAQs, guides and contact support',
                                              onTap: () => _support(false),
                                            ),
                                            _SupportTile(
                                              title: 'Privacy & Security',
                                              subtitle: 'Manage your privacy and account security',
                                              onTap: () => _support(true),
                                            ),
                                          ];
                                          return normalText
                                              ? Row(
                                                  children: [
                                                    Expanded(child: tiles[0]),
                                                    const SizedBox(width: 7),
                                                    Expanded(child: tiles[1]),
                                                  ],
                                                )
                                              : Column(children: tiles);
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      BThereButton(
                                        label: 'Log out',
                                        variant: BThereButtonVariant.outlined,
                                        leadingIcon: const Icon(
                                          Icons.logout_rounded,
                                        ),
                                        loading: signOut.busy,
                                        onPressed: busy ? null : _signOut,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: normalText
                                  ? HomeScale(child: content)
                                  : Center(child: content),
                            ),
                          );
                        },
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

  Future<void> _editGlobal(String section, ProfileSupplement? value) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _GlobalProfileEditor(
        section: section,
        initial: value,
        repository: ref.read(profileSupplementRepositoryProvider),
      ),
    );
    if (saved == true && mounted) ref.invalidate(profileSupplementProvider);
  }

  Future<void> _editDocument(ProfileDocumentRequirement entry) async {
    final subscription = ref.listenManual(
      documentsControllerProvider(entry.serviceTypeId),
      (_, _) {},
    );
    try {
      final controller = ref.read(
        documentsControllerProvider(entry.serviceTypeId).notifier,
      );
      await controller.load();
      if (!mounted) return;
      controller.edit(entry.requirement);
      if (ref.read(documentsControllerProvider(entry.serviceTypeId)).draft ==
          null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This document cannot be edited right now.'),
          ),
        );
        return;
      }
      final container = ProviderScope.containerOf(context);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: DocumentEditorSheet(serviceTypeId: entry.serviceTypeId),
        ),
      );
      if (mounted) {
        controller.cancel();
        ref.invalidate(profileDocumentsProvider);
      }
    } finally {
      subscription.close();
    }
  }

  Future<void> _documentManager() async => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Documents & Verification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DocumentsPanel(onEdit: _editDocument),
          ],
        ),
      ),
    ),
  );

  Future<void> _support(bool privacy) async => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(providerSignOutProvider);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  privacy ? 'Privacy & Security' : 'Help & Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  privacy ? 'Sign out to end your session on this device.' : 'Expand an account section to view your details, then choose Edit to update them. Contact support details are not available yet.',
                ),
                const SizedBox(height: 16),
                if (privacy) ...[
                  if (state.error != null) BThereInlineError(state.error!),
                  BThereButton(
                    key: const ValueKey('profile-sign-out'),
                    label: 'Sign out',
                    loading: state.busy,
                    onPressed: state.busy ? null : _signOut,
                  ),
                  IconButton(
                    key: const ValueKey('refresh-profile'),
                    tooltip: 'Refresh profile',
                    onPressed: state.busy ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ] else
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      this.context.go(AppRoutes.services);
                    },
                    child: const Text('Manage services'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
