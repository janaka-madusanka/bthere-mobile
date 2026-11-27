import '../../../app/widgets/customer_content_surface.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../../booking/presentation/booking_ui_format.dart';
import '../../booking/presentation/customer_booking_details_screen.dart'
    show bookingStatusLabel;
import '../../booking/presentation/booking_details_skeleton.dart';
import '../../discovery/presentation/customer_bottom_navigation.dart';
import '../../wallet/data/customer_wallet_repository.dart' show walletMoney;
import '../data/customer_profile_overview_repository.dart';
import 'profile_contact_sheet.dart';
import 'profile_document_sheet.dart';
import 'profile_requests_screen.dart';
import '../domain/customer_document.dart';

class CustomerProfileOverviewScreen extends ConsumerStatefulWidget {
  const CustomerProfileOverviewScreen({super.key});
  @override
  ConsumerState<CustomerProfileOverviewScreen> createState() =>
      _CustomerProfileOverviewScreenState();
}

class _CustomerProfileOverviewScreenState
    extends ConsumerState<CustomerProfileOverviewScreen>
    with WidgetsBindingObserver {
  static const _navy = Color(0xFF10143F);
  static const _muted = Color(0xFF7B819F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      refresh();
    }
  }

  void refresh() {
    final owner = ref.read(customerAuthControllerProvider).user?.id;
    if (owner != null) ref.invalidate(customerProfileOverviewProvider(owner));
  }

  Widget panel(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: CustomerColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget title(String text, {VoidCallback? all}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: text == 'Pending services' || text == 'Service history'
            ? const LinearGradient(colors: [Color(0xFFE9F8F6), Colors.white])
            : null,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: text == 'Pending services' || text == 'Service history'
              ? 12
              : 0,
          vertical: 6,
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final heading = Text(
              text,
              style: CustomerTypography.section.copyWith(color: _navy),
            );
            final action = all == null
                ? null
                : TextButton.icon(
                    onPressed: all,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right, size: 18),
                    label: const Text('View all'),
                  );
            if (bounds.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  if (action != null)
                    Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                ?action,
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget badge(String label, bool verified) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: verified ? const Color(0xFFE3F8EF) : const Color(0xFFF2F5F8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: CustomerTypography.compactStrong.copyWith(
        color: verified
            ? const Color(0xFF16845F)
            : CustomerColors.secondaryText,
      ),
    ),
  );
  Future<void> contacts(Map data) async {
    final owner = ref.read(customerAuthControllerProvider).user?.id;
    if (owner == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => ProfileContactSheet(
        owner: owner,
        contacts: Map<String, dynamic>.from(data),
      ),
    );
    if (mounted) refresh();
  }

  Future<void> document(Map<String, dynamic> data) async {
    final owner = ref.read(customerAuthControllerProvider).user?.id;
    if (owner == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8F9FE),
      builder: (_) => ProfileDocumentSheet(owner: owner, document: data),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(customerAuthControllerProvider);
    final owner = auth.user?.id;
    final overview = owner == null
        ? null
        : ref.watch(customerProfileOverviewProvider(owner));
    return Theme(
      data: CustomerTheme.authentication(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Profile',
            style: CustomerTypography.section.copyWith(color: Colors.black),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: CustomerColors.primary,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        bottomNavigationBar: const CustomerBottomNavigation(
          selected: CustomerNavigationTab.profile,
        ),
        body: CustomerContentSurface(
          child: overview == null
              ? const SizedBox.shrink()
              : overview.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => const BookingDetailsPageSkeleton(),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Profile could not be loaded.'),
                        TextButton(
                          onPressed: refresh,
                          child: const Text('Retry profile'),
                        ),
                      ],
                    ),
                  ),
                  data: (data) {
                    final profile = data['profile'] as Map?;
                    final contact = data['contacts'] as Map;
                    final stats = data['statistics'] as Map;
                    final pending = data['pendingServices'] as Map;
                    final history = data['serviceHistory'] as Map;
                    final photo = profile?['profilePhoto'];
                    final uri = photo is String ? Uri.tryParse(photo) : null;
                    return RefreshIndicator(
                      onRefresh: () async {
                        refresh();
                        await ref.read(
                          customerProfileOverviewProvider(owner!).future,
                        );
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _identity(profile, photo, uri),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, bounds) {
                                    final stacked =
                                        bounds.maxWidth < 290 ||
                                        MediaQuery.textScalerOf(context)
                                                .scale(14) >
                                            20;
                                    final width = stacked
                                        ? bounds.maxWidth
                                        : (bounds.maxWidth - 16) / 3;
                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        SizedBox(
                                          width: width,
                                          child: _stat(
                                            Icons.pending_actions,
                                            '${stats['pendingCount']}',
                                            'Pending services',
                                            const Color(0xFFECFAF7),
                                            const Color(0xFF009B98),
                                          ),
                                        ),
                                        SizedBox(
                                          width: width,
                                          child: _stat(
                                            Icons.calendar_today_outlined,
                                            '${stats['completedCount']}',
                                            'Completed',
                                            const Color(0xFFF6F0FE),
                                            const Color(0xFF8145DB),
                                          ),
                                        ),
                                        SizedBox(
                                          width: width,
                                          child: _spending(
                                            stats['spending'] as List,
                                            'Total spent',
                                            const Color(0xFFFFF8ED),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                if ((stats['excludedPaymentCount'] as int) > 0)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Some payments are being processed.',
                                      style: CustomerTypography.compact,
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                title('Account'),
                                panel([
                                  _contactRow(
                                    Icons.phone_outlined,
                                    'Phone number',
                                    contact['phoneNumber'],
                                    contact['phoneVerified'] == true,
                                  ),
                                  const Divider(height: 22),
                                  _contactRow(
                                    Icons.email_outlined,
                                    'Email address',
                                    contact['email'],
                                    contact['emailVerified'] == true,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFEDF9FA),
                                      foregroundColor: CustomerColors.action,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => contacts(contact),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          child: Text('Manage contact details'),
                                        ),
                                        Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                ]),
                                title('My documents'),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Upload and manage your personal documents',
                                    style: CustomerTypography.body,
                                  ),
                                ),
                                _documents(data['documents'] as List),
                                title(
                                  'Pending services',
                                  all:
                                      pending['hasMore'] == true ||
                                          (pending['totalCount'] as int) >
                                              CustomerProfileOverviewRepository
                                                  .recentLimit ||
                                          (pending['items'] as List).length >
                                              CustomerProfileOverviewRepository
                                                  .recentLimit
                                      ? () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ProfileRequestsScreen(),
                                          ),
                                        )
                                      : null,
                                ),
                                panel([
                                  if ((pending['items'] as List).isEmpty)
                                    const Text(
                                      'No pending services.',
                                      style: CustomerTypography.body,
                                    ),
                                  for (final row
                                      in (pending['items'] as List).take(
                                        CustomerProfileOverviewRepository
                                            .recentLimit,
                                      ))
                                    _service(
                                      Map<String, dynamic>.from(row as Map),
                                    ),
                                ]),
                                title(
                                  'Service history',
                                  all: () => context.push('/opportunities'),
                                ),
                                panel([
                                  if ((history['items'] as List).isEmpty)
                                    const Text(
                                      'No service history yet.',
                                      style: CustomerTypography.body,
                                    ),
                                  for (final row
                                      in (history['items'] as List).take(
                                        CustomerProfileOverviewRepository
                                            .recentLimit,
                                      ))
                                    _service(
                                      Map<String, dynamic>.from(row as Map),
                                    ),
                                ]),
                                _accountAction(
                                  key: const ValueKey(
                                    'customer-account-signout',
                                  ),
                                  label: auth.busy
                                      ? 'Signing out...'
                                      : 'Sign out',
                                  icon: Icons.logout_rounded,
                                  danger: true,
                                  onTap: auth.busy ? null : auth.logout,
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
    );
  }

  Widget _accountAction({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool danger = false,
  }) {
    final colour = danger ? CustomerColors.error : CustomerColors.action;
    return Material(
      key: key,
      color: danger ? const Color(0xFFFFF4F5) : const Color(0xFFEDF9F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: danger ? const Color(0xFFF6DFE2) : const Color(0xFFD6EEEB),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _bubble(icon, colour, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: CustomerTypography.compactStrong.copyWith(
                    color: colour,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colour, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identity(Map? profile, dynamic photo, Uri? uri) => LayoutBuilder(
    builder: (context, bounds) {
      final edit = profile == null
          ? TextButton(
              onPressed: () => context.go('/profile'),
              child: const Text('Complete profile'),
            )
          : IconButton.filledTonal(
              tooltip: 'Edit profile',
              onPressed: () => context.go('/profile'),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE4F7F3),
                foregroundColor: CustomerColors.action,
              ),
              icon: const Icon(Icons.edit_outlined, size: 22),
            );
      final narrow =
          profile == null ||
          bounds.maxWidth < 310 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 43,
                backgroundColor: CustomerColors.selection,
                child: uri != null && {'http', 'https'}.contains(uri.scheme)
                    ? ClipOval(
                        child: Image.network(
                          photo as String,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.person_outline, size: 36),
                        ),
                      )
                    : const Icon(Icons.person_outline, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?['displayName'] as String? ??
                          'Complete your profile',
                      style: CustomerTypography.screen.copyWith(color: _navy),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F9FA),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Client account',
                        style: CustomerTypography.compactStrong.copyWith(
                          color: CustomerColors.action,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[const SizedBox(width: 8), edit],
            ],
          ),
          if (narrow) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: edit),
          ],
        ],
      );
    },
  );

  Widget _bubble(IconData icon, Color colour, {double size = 36}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colour.withValues(alpha: .10),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: size * .55, color: colour),
  );

  Widget _stat(
    IconData icon,
    String value,
    String label,
    Color colour,
    Color accent,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bubble(icon, accent, size: 42),
        const SizedBox(height: 10),
        Text(
          value,
          textAlign: TextAlign.center,
          style: CustomerTypography.screen.copyWith(color: _navy),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: CustomerTypography.compact.copyWith(color: _muted),
        ),
      ],
    ),
  );
  Widget _spending(List values, String label, Color colour) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bubble(Icons.bar_chart_rounded, const Color(0xFFF1A111), size: 42),
        const SizedBox(height: 10),
        if (values.isEmpty)
          Text(
            'No real payments yet',
            textAlign: TextAlign.center,
            style: CustomerTypography.compactStrong.copyWith(color: _navy),
          ),
        for (final raw in values)
          Text(
            '${raw['currencyCode']} ${walletMoney(raw['totalSpent']).replaceFirst('Rs. ', '')}',
            textAlign: TextAlign.center,
            style: CustomerTypography.card.copyWith(
              color: _navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: CustomerTypography.compact.copyWith(color: _muted),
        ),
      ],
    ),
  );
  Widget _contactRow(
    IconData icon,
    String label,
    dynamic value,
    bool verified,
  ) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow =
          bounds.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bubble(icon, CustomerColors.action, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CustomerTypography.card.copyWith(color: _navy),
                ),
                const SizedBox(height: 4),
                Text(
                  value as String? ?? 'Not added',
                  style: CustomerTypography.compact.copyWith(color: _muted),
                ),
                if (narrow) ...[
                  const SizedBox(height: 7),
                  badge(verified ? 'Verified' : 'Not verified', verified),
                ],
              ],
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: 8),
            badge(verified ? 'Verified' : 'Not verified', verified),
          ],
        ],
      );
    },
  );
  Widget _statusBadge(String status, {bool document = false}) {
    final (label, ink, fill) = switch (status) {
      'COMPLETED' => (
        'Completed',
        const Color(0xFF009C69),
        const Color(0xFFE1F8ED),
      ),
      'PROVIDED' when document => (
        'Saved',
        CustomerColors.action,
        CustomerColors.selection,
      ),
      'APPROVED' when document => (
        'Verified',
        const Color(0xFF009C69),
        const Color(0xFFE1F8ED),
      ),
      'CANCELLED' => (
        'Cancelled',
        const Color(0xFFEA3A70),
        const Color(0xFFFFE6EF),
      ),
      'REJECTED' => (
        'Rejected',
        const Color(0xFFD9405A),
        const Color(0xFFFFE9EE),
      ),
      'MATCHING' => (
        'Awaiting provider',
        const Color(0xFFD88710),
        const Color(0xFFFFF0D2),
      ),
      'CONFIRMED' => (
        'Provider assigned',
        const Color(0xFF1688DC),
        const Color(0xFFE1F2FF),
      ),
      'MISSING' => (
        'No documents',
        const Color(0xFF7D8294),
        const Color(0xFFF0F0F3),
      ),
      'PENDING' when document => (
        'Under review',
        const Color(0xFFD88710),
        const Color(0xFFFFF0D2),
      ),
      _ => (
        bookingStatusLabel(status),
        CustomerColors.action,
        CustomerColors.selection,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: CustomerTypography.compactStrong.copyWith(color: ink),
      ),
    );
  }

  Widget _documents(List raw) {
    final documents = _sortedDocuments(raw);
    final missing = documents
        .where(
          (d) =>
              d['status'] == 'MISSING' &&
              (d['fileKeys'] as List? ?? []).isEmpty,
        )
        .toList();
    final uploaded = documents.where((d) => !missing.contains(d)).toList();
    Widget rows(List<Map<String, dynamic>> items) => Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0xFFEBEEF5)),
          _document(items[i]),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (documents.isEmpty)
          const Text(
            'No documents are required right now.',
            style: CustomerTypography.body,
          ),
        if (documents.isNotEmpty && missing.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFAF7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: CustomerColors.action,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All documents uploaded',
                    style: CustomerTypography.compactStrong.copyWith(
                      color: CustomerColors.action,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: rows(missing),
          ),
        if (uploaded.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Uploaded documents',
              style: CustomerTypography.body.copyWith(
                color: _muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          panel([rows(uploaded)]),
        ],
      ],
    );
  }

  Widget _document(Map<String, dynamic> d) => LayoutBuilder(
    builder: (context, bounds) {
      final narrow =
          bounds.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      final needsUpload = d['actionRequired'] == true;
      final unsubmitted =
          d['status'] == 'MISSING' && (d['fileKeys'] as List? ?? []).isEmpty;
      final actions = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!unsubmitted) ...[
            _statusBadge(d['status'] as String, document: true),
            const SizedBox(height: 4),
          ],
          OutlinedButton.icon(
            icon: Icon(
              needsUpload
                  ? Icons.file_upload_outlined
                  : Icons.visibility_outlined,
              size: 15,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 30),
              visualDensity: VisualDensity.compact,
              foregroundColor: CustomerColors.action,
              side: const BorderSide(color: Color(0xFF9FDFDE)),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            ),
            onPressed: () => document(d),
            label: Text(
              d['actionRequired'] == true
                  ? (d['statusReason'] == 'NOT_SUBMITTED'
                        ? 'Upload'
                        : 'Upload again')
                  : 'View',
              style: CustomerTypography.compactStrong,
            ),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 36,
              decoration: BoxDecoration(
                color: CustomerColors.selection,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                unsubmitted ? Icons.badge_outlined : Icons.description_outlined,
                color: CustomerColors.action,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['name'] as String,
                    style: CustomerTypography.compactStrong.copyWith(
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (d['services'] as List)
                        .map(
                          (s) =>
                              s['optionName'] ??
                              s['serviceName'] ??
                              'All services',
                        )
                        .toSet()
                        .join(', '),
                    style: CustomerTypography.compact.copyWith(color: _muted),
                  ),
                  if (d['reviewedAt'] is String)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Reviewed: ${bookingDisplayTime(context, d['reviewedAt'] as String)}',
                        style: CustomerTypography.compact.copyWith(
                          color: _muted,
                        ),
                      ),
                    ),
                  if (d['expiresOn'] is String)
                    Text(
                      'Expires: ${d['expiresOn']}',
                      style: CustomerTypography.compact.copyWith(color: _muted),
                    ),
                  if (documentReason(d) != null)
                    Text(
                      documentReason(d)!,
                      style: CustomerTypography.compact.copyWith(
                        color: CustomerColors.error,
                      ),
                    ),
                  if (narrow) ...[const SizedBox(height: 8), actions],
                ],
              ),
            ),
            if (!narrow) ...[const SizedBox(width: 10), actions],
          ],
        ),
      );
    },
  );
  Widget _service(Map<String, dynamic> row) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () async {
        if (row['jobId'] is int) {
          await context.push('/bookings/${row['jobId']}');
        } else if (row['requestId'] is int) {
          await showProfileRequest(context, ref, row['requestId'] as int);
        }
        if (mounted) refresh();
      },
      child: LayoutBuilder(
        builder: (context, bounds) {
          final narrow =
              bounds.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final status = row['status'] as String;
          final accent = status == 'CANCELLED'
              ? const Color(0xFFEA3A70)
              : status == 'MATCHING'
              ? const Color(0xFFE49B15)
              : CustomerColors.action;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusBadge(status),
              if (row['amount'] is num && row['currencyCode'] is String)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${row['currencyCode']} ${walletMoney(row['amount']).replaceFirst('Rs. ', '')}',
                    style: CustomerTypography.compact.copyWith(color: _muted),
                  ),
                ),
            ],
          );
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEF1F6))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _bubble(Icons.event_note_outlined, accent, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['optionName'] as String? ??
                            row['serviceName'] as String? ??
                            'Service booking',
                        style: CustomerTypography.compactStrong.copyWith(
                          color: _navy,
                        ),
                      ),
                      if (row['startAt'] is String) ...[
                        const SizedBox(height: 4),
                        Text(
                          bookingDisplayTime(context, row['startAt'] as String),
                          style: CustomerTypography.compact.copyWith(
                            color: _muted,
                          ),
                        ),
                      ],
                      if (narrow) ...[const SizedBox(height: 7), summary],
                    ],
                  ),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 8),
                  Flexible(child: summary),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _muted, size: 20),
              ],
            ),
          );
        },
      ),
    ),
  );
}

List<Map<String, dynamic>> _sortedDocuments(List raw) {
  final unique = <int, Map<String, dynamic>>{};
  for (final item in raw) {
    final row = Map<String, dynamic>.from(item as Map);
    unique.putIfAbsent(row['requirementId'] as int, () => row);
  }
  return [
    for (final needed in [true, false])
      ...unique.values.where(
        (row) => (row['actionRequired'] == true) == needed,
      ),
  ];
}
