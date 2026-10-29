import 'dart:async';

import 'package:bthere_common/bthere_common.dart';
import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../application/application_status_controller.dart';
import '../documents/documents_controller.dart';
import '../documents/documents_screen.dart';
import 'registration_widgets.dart';
import 'service_setup_screen.dart';

String applicationItemRoute(int serviceTypeId, ApplicationReviewItem? item) {
  if (item == null) return '/services/$serviceTypeId/register?details=1';
  return switch (item.kind) {
    ApplicationItemKind.document ||
    ApplicationItemKind.certificate ||
    ApplicationItemKind.education => '/services/$serviceTypeId/setup/documents',
    ApplicationItemKind.skill => '/services/$serviceTypeId/setup/skills',
    ApplicationItemKind.field || ApplicationItemKind.option =>
      '/services/$serviceTypeId/register?details=1${item.optionId == null ? '' : '&optionId=${item.optionId}'}',
  };
}

class ApplicationStatusScreen extends ConsumerStatefulWidget {
  const ApplicationStatusScreen({required this.serviceTypeId, super.key});
  final int serviceTypeId;
  @override
  ConsumerState<ApplicationStatusScreen> createState() =>
      _ApplicationStatusState();
}

class _ApplicationStatusState extends ConsumerState<ApplicationStatusScreen>
    with WidgetsBindingObserver {
  bool editing = false;
  String? actionError;
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

  Future<void> refresh() => ref
      .read(applicationStatusProvider(widget.serviceTypeId).notifier)
      .refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !editing) unawaited(refresh());
  }

  Future<void> openItem(ApplicationReviewItem? item) async {
    if (editing) return;
    setState(() {
      editing = true;
      actionError = null;
    });
    try {
      if (item?.kind == ApplicationItemKind.document &&
          item!.needsCorrection &&
          item.document != null) {
        final container = ref.container;
        final provider = documentsControllerProvider(widget.serviceTypeId);
        final subscription = container.listen(provider, (_, _) {});
        try {
          final controller = container.read(provider.notifier);
          await controller.load();
          if (!mounted) return;
          controller.edit(item.document!);
          if (container.read(provider).draft == null) {
            throw StateError('Document unavailable');
          }
          await showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
            builder: (_) => UncontrolledProviderScope(
              container: container,
              child: DocumentEditorSheet(serviceTypeId: widget.serviceTypeId),
            ),
          );
        } finally {
          subscription.close();
        }
      } else {
        await context.push(applicationItemRoute(widget.serviceTypeId, item));
      }
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              actionError = 'Unable to open this item. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => editing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationStatusProvider(widget.serviceTypeId)),
        result = state.asData?.value;
    if (result is Success<ApplicationStatusData> &&
        !result.value.rejected &&
        (result.value.approved || result.value.inactive)) {
      return ServiceSetupScreen(
        serviceTypeId: widget.serviceTypeId,
        showStatus: true,
      );
    }
    Widget content;
    if (state.isLoading) {
      content = const Padding(
        padding: EdgeInsets.all(40),
        child: BThereLoadingState(label: 'Loading application status'),
      );
    } else if (result is Success<ApplicationStatusData> &&
        (result.value.pending || result.value.rejected)) {
      content = ApplicationStatusView(
        data: result.value,
        busy: editing,
        error: actionError,
        onItem: openItem,
        onUpdate: () => openItem(result.value.correction),
        onHome: () => context.go(AppRoutes.home),
      );
    } else {
      content = BThereStateView(
        title: 'Unable to load application status',
        message: 'Please try again.',
        action: RegistrationButton('Retry', onPressed: refresh),
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
      child: RegistrationPage(
        step: 1,
        title: 'Application Status',
        showProgress: false,
        alwaysScrollable: true,
        contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
        onBack: () => context.go(AppRoutes.services),
        child: content,
      ),
    );
  }
}

class ApplicationStatusAsset extends StatelessWidget {
  const ApplicationStatusAsset(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/application_status/$name.svg',
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class ApplicationStatusView extends StatelessWidget {
  const ApplicationStatusView({
    required this.data,
    required this.onItem,
    required this.onUpdate,
    required this.onHome,
    this.busy = false,
    this.error,
    super.key,
  });
  final ApplicationStatusData data;
  final ValueChanged<ApplicationReviewItem> onItem;
  final VoidCallback onUpdate, onHome;
  final bool busy;
  final String? error;
  Text text(
    String label,
    double size, {
    Color color = const Color(0xFF060B43),
    bool bold = false,
    String font = 'Nunito',
  }) => registrationText(
    label,
    size,
    color: color,
    bold: bold,
    fontFamily: font,
    weight: bold ? FontWeight.w800 : FontWeight.w500,
  );
  @override
  Widget build(BuildContext context) {
    final rejected = data.rejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: rejected ? 276 : 260,
            height: rejected ? 184 : 174,
            child: Image.asset(
              'assets/application_status/${rejected ? 'rejected_rejected' : 'review_review'}_illustration.png',
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        SizedBox(height: rejected ? 8 : 18),
        Text(
          rejected
              ? 'Your application was not approved'
              : 'Your application is Under Review',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: rejected ? 22 : 24,
            fontWeight: FontWeight.w800,
            height: 1.22,
            color: const Color(0xFF060B43),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rejected
              ? 'We\'ve reviewed your details and some items didn\'t meet the requirements. You can update the requested information and resubmit your application.'
              : 'We are checking your details and submitted documents.\nYou will receive an update within 1-2 days.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7D80A5),
          ),
        ),
        const SizedBox(height: 16),
        if (!rejected) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFBFA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8F9F5),
                    shape: BoxShape.circle,
                  ),
                  child: const ApplicationStatusAsset('review_clock'),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      text('Review in progress', 16, bold: true),
                      const SizedBox(height: 3),
                      text(
                        'Submitted successfully. Awaiting Verification',
                        12,
                        color: const Color(0xFF7D80A5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const Divider(height: 1, thickness: 1, color: Color(0xFFEAECF3)),
        if (rejected && data.reason?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          RegistrationNotice('Service review: ${data.reason}', warning: true),
        ],
        const SizedBox(height: 16),
        text('What we are reviewing', 17, bold: true, font: 'HomeLato'),
        const SizedBox(height: 4),
        text(
          'Track the status of each item below.',
          12.2,
          color: const Color(0xFF7D80A5),
          font: 'HomeLato',
        ),
        const SizedBox(height: 12),
        if (data.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: text(
              'No individual review items are available yet.',
              13,
              color: registrationMuted,
            ),
          ),
        for (final (index, item) in data.items.indexed) ...[
          if (index > 0)
            const Divider(height: 1, thickness: 1, color: Color(0xFFEAECF3)),
          _reviewItem(item, rejected),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: rejected ? const Color(0xFFE3F2FD) : const Color(0xFFE0F2F1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              if (rejected)
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFBBDEFB),
                    shape: BoxShape.circle,
                  ),
                  child: const ApplicationStatusAsset('rejected_bell'),
                )
              else
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: ApplicationStatusAsset('review_notification'),
                ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text(
                      rejected
                          ? 'You can resubmit your application'
                          : "We will notify you when there's an update",
                      14,
                      bold: true,
                      color: rejected
                          ? const Color(0xFF1976D2)
                          : const Color(0xFF00796B),
                    ),
                    text(
                      rejected
                          ? "Once you've updated the requested items, you can submit again"
                          : 'You can safely leave this screen and check back anytime.',
                      10,
                      color: const Color(0xFF616161),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          RegistrationNotice(error!, warning: true),
        ],
        const SizedBox(height: 20),
        RegistrationButton(
          rejected ? 'Update and Resubmit' : 'Go to Home',

          onPressed: busy ? null : (rejected ? onUpdate : onHome),
        ),
        if (rejected) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 47,
            child: TextButton(
              onPressed: busy ? null : onHome,
              child: text('Go to Home', 14, color: const Color(0xFF0097A7)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewItem(ApplicationReviewItem item, bool rejected) {
    final (label, background, foreground) = switch (item.state) {
      ApplicationItemState.approved => (
        rejected ? 'Approved' : 'Reviewed',
        rejected ? const Color(0xFFE8F5E9) : const Color(0xFFE7F7FF),
        rejected ? const Color(0xFF43A047) : const Color(0xFF00A5F7),
      ),
      ApplicationItemState.rejected => (
        'Rejected',
        const Color(0xFFFFEBEE),
        const Color(0xFFE53935),
      ),
      ApplicationItemState.reuploaded => (
        'Document re-uploaded',
        const Color(0xFFE7F7FF),
        const Color(0xFF00A5F7),
      ),
      ApplicationItemState.pending => (
        'Under Review',
        const Color(0xFFFFF3E0),
        const Color(0xFFFB8C00),
      ),
      ApplicationItemState.missing => (
        'Not submitted',
        const Color(0xFFFFF3E0),
        const Color(0xFFFB8C00),
      ),
      ApplicationItemState.expired => (
        'Expired',
        const Color(0xFFFFEBEE),
        const Color(0xFFE53935),
      ),
      ApplicationItemState.unknown => (
        'Status unavailable',
        const Color(0xFFF0F1F8),
        registrationMuted,
      ),
    };
    final prefix = rejected ? 'rejected' : 'review';
    return InkWell(
      key: ValueKey('review-item-${item.id}'),
      onTap: (rejected || item.needsCorrection) && !busy
          ? () => onItem(item)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: ApplicationStatusAsset(
                '${prefix}_${item.kind == ApplicationItemKind.certificate || item.kind == ApplicationItemKind.education || item.label.toLowerCase().contains('certificate') ? 'certificate' : 'document'}',
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text(item.label, 14),
                  if (item.reason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    text(item.reason!, 10, color: const Color(0xFF7D80A5)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 75),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  widthFactor: 1,
                  child: text(
                    label,
                    9,
                    color: foreground,
                    bold: true,
                    font: 'HomeLato',
                  ),
                ),
              ),
            ),
            if (rejected) ...[
              const SizedBox(width: 15),
              const SizedBox(
                width: 24,
                height: 24,
                child: ApplicationStatusAsset('rejected_chevron'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
