import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_theme.dart';
import 'booking_details_skeleton.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../domain/booking_models.dart';

/// Explicit, once-per-provider feedback. Unknown writes are reconciled by GET.
class CustomerBookingRating extends ConsumerStatefulWidget {
  const CustomerBookingRating({
    super.key,
    required this.jobId,
    this.autoOpen = false,
    this.onSavedState,
  });
  final int jobId;
  final bool autoOpen;
  final ValueChanged<bool>? onSavedState;
  @override
  ConsumerState<CustomerBookingRating> createState() =>
      _CustomerBookingRatingState();
}

class _CustomerBookingRatingState extends ConsumerState<CustomerBookingRating>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true, working = false, uncertain = false;
  int? owner;
  late final CustomerAuthController _auth;
  final comment = TextEditingController();
  int stars = 0;
  int? selected;
  final Map<int, Map<String, dynamic>> acknowledged = {};
  bool identityLost = false;
  bool get alive =>
      mounted &&
      !identityLost &&
      owner != null &&
      ref.read(customerAuthControllerProvider).user?.id == owner &&
      ref.read(customerAuthControllerProvider).stage ==
          CustomerAuthStage.authenticated;
  bool get canSubmit =>
      alive &&
      !working &&
      !loading &&
      !uncertain &&
      data?['canRate'] == true &&
      data?['jobStatus'] == 'COMPLETED' &&
      stars >= 1 &&
      stars <= 5 &&
      selected != null &&
      (data?['providers'] as List? ?? []).any(
        (p) => p['providerId'] == selected && p['rated'] == false,
      );

  @override
  void initState() {
    super.initState();
    _auth = ref.read(customerAuthControllerProvider);
    owner = _auth.user?.id;
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_identityChanged);
    load();
  }

  Future<void> load() async {
    if (!alive) return;
    _update(() => loading = true);
    try {
      final result = await ref
          .read(customerBookingRepositoryProvider)
          .bookingRatings(widget.jobId);
      if (!alive) return;
      for (final raw in result['providers'] as List) {
        final p = raw as Map<String, dynamic>;
        if (acknowledged.containsKey(p['providerId'])) {
          p['rated'] = true;
          p['rating'] = acknowledged[p['providerId']];
        }
      }
      _update(() {
        data = result;
        uncertain = false;
        error = null;
      });
    } catch (_) {
      if (alive) {
        _update(
          () => error = 'Ratings could not be loaded. Please check again.',
        );
      }
    } finally {
      if (alive) {
        _update(() => loading = false);
        final rows = data?['providers'] as List? ?? [];
        final saved = rows.isNotEmpty && rows.every((p) => p['rated'] == true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (alive) widget.onSavedState?.call(saved);
        });
        _maybeAutoOpen();
      }
    }
  }

  Future<void> submit() async {
    if (!canSubmit) return;
    final providerId = selected!;
    final rating = stars;
    _update(() {
      working = true;
      error = null;
    });
    try {
      await ref
          .read(customerBookingRepositoryProvider)
          .rateProvider(widget.jobId, providerId, rating, comment.text);
      if (!alive) return;
      acknowledged[providerId] = {
        'rating': rating,
        'comment': comment.text.trim(),
      };
      // Keep acknowledged feedback visible even if the following GET fails.
      for (final raw in data!['providers'] as List) {
        final p = raw as Map<String, dynamic>;
        if (p['providerId'] == providerId) {
          p['rated'] = true;
          p['rating'] = {'rating': rating, 'comment': comment.text.trim()};
        }
      }
      selected = null;
      stars = 0;
      comment.clear();
      await load();
      if (alive) _closeSheet();
    } catch (failure) {
      if (!alive) return;
      uncertain = true;
      await load();
      if (alive) {
        final saved = (data?['providers'] as List? ?? []).any(
          (p) => p['providerId'] == providerId && p['rated'] == true,
        );
        _update(() {
          if (saved) {
            selected = null;
            stars = 0;
            comment.clear();
            error = null;
          } else {
            error = failure is BookingProblem ? failure.message : 'Your rating could not be confirmed. Check its status before submitting again.';
          }
        });
        if (saved) _closeSheet();
      }
    } finally {
      if (alive) _update(() => working = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_identityChanged);
    _sheetSetState = null;
    final sheet = _sheetContext;
    if (sheet != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sheet.mounted && ModalRoute.of(sheet)?.isCurrent == true) {
          Navigator.of(sheet).pop();
        }
      });
    }
    comment.dispose();
    super.dispose();
  }

  StateSetter? _sheetSetState;
  BuildContext? _sheetContext;
  bool _sheetOpen = false, _autoPrompted = false;

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _sheetSetState?.call(() {});
  }

  void _identityChanged() {
    if (alive) return;
    identityLost = true;
    comment.clear();
    stars = 0;
    _update(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeSheet());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _closeSheet() {
    final sheet = _sheetContext;
    if (sheet != null &&
        sheet.mounted &&
        ModalRoute.of(sheet)?.isCurrent == true) {
      Navigator.of(sheet).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeAutoOpen();
  }

  @override
  void didUpdateWidget(CustomerBookingRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoOpen && !oldWidget.autoOpen) _maybeAutoOpen();
  }

  void _maybeAutoOpen() {
    if (!widget.autoOpen ||
        _autoPrompted ||
        !alive ||
        loading ||
        working ||
        uncertain ||
        data?['canRate'] != true ||
        data?['jobStatus'] != 'COMPLETED') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!alive ||
          _autoPrompted ||
          _sheetOpen ||
          ModalRoute.of(context)?.isCurrent != true ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      final provider = (data?['providers'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((p) => p['rated'] == false)
          .firstOrNull;
      if (provider == null) return;
      _autoPrompted = true;
      _openProvider(provider);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openProvider(Map<String, dynamic> provider) async {
    if (!alive ||
        _sheetOpen ||
        working ||
        loading ||
        uncertain ||
        provider['rated'] != false ||
        data?['canRate'] != true ||
        data?['jobStatus'] != 'COMPLETED') {
      return;
    }
    _update(() {
      selected = provider['providerId'] as int;
      stars = 0;
      comment.clear();
    });
    _sheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFFF7F5FC),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => StatefulBuilder(
          builder: (sheet, updateSheet) {
            _sheetContext = sheet;
            _sheetSetState = updateSheet;
            if (!alive) return const SizedBox.shrink();
            return _reviewSheet(sheet, provider);
          },
        ),
      );
    } finally {
      _sheetSetState = null;
      _sheetContext = null;
      _sheetOpen = false;
    }
  }

  Widget _reviewSheet(BuildContext sheet, Map<String, dynamic> provider) =>
      SingleChildScrollView(
        key: const ValueKey('booking-rating-sheet'),
        padding: EdgeInsets.fromLTRB(
          24,
          4,
          24,
          MediaQuery.viewInsetsOf(sheet).bottom + 36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rate the Service',
                    style: CustomerTypography.screen.copyWith(
                      color: const Color(0xFF101D42),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close review',
                  onPressed: working ? null : _closeSheet,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Share your experience with this provider.',
              style: CustomerTypography.body.copyWith(
                color: CustomerColors.secondaryText,
              ),
            ),
            if ((data?['providers'] as List? ?? []).length > 1) ...[
              const SizedBox(height: 6),
              Text(
                provider['displayName'] as String? ?? 'Your provider',
                style: CustomerTypography.compactStrong,
              ),
            ],
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, bounds) => Row(
                children: [
                  for (var index = 0; index < 5; index++)
                    Expanded(
                      child: IconButton(
                        key: ValueKey('rating-star-${index + 1}'),
                        tooltip: '${index + 1} stars',
                        onPressed: working || loading || uncertain
                            ? null
                            : () => _update(() => stars = index + 1),
                        iconSize: (bounds.maxWidth / 5 - 8).clamp(28, 54),
                        padding: const EdgeInsets.all(3),
                        icon: Icon(
                          index < stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: index < stars
                              ? const Color(0xFFFFBC00)
                              : const Color(0xFFBBC1CD),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: comment,
              enabled: !working && !uncertain,
              maxLength: 250,
              minLines: 3,
              maxLines: 4,
              style: CustomerTypography.body,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                filled: true,
                fillColor: const Color(0xFFF7F5FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCFD6E2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCFD6E2)),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  error!,
                  style: CustomerTypography.compact.copyWith(
                    color: CustomerColors.error,
                  ),
                ),
              ),
            if (error != null || uncertain)
              TextButton(
                onPressed: working ? null : load,
                child: const Text('Check rating status'),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('submit-provider-rating'),
              style: FilledButton.styleFrom(
                backgroundColor: CustomerColors.action,
                foregroundColor: Colors.white,
                textStyle: CustomerTypography.card.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: canSubmit ? submit : null,
              child: Text(working ? 'Submitting...' : 'Submit Review'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    ref.watch(customerAuthControllerProvider);
    if (!alive) return const SizedBox.shrink();
    if (loading && data == null) {
      return const BookingDetailsSkeleton(review: true);
    }
    final providers = (data?['providers'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final unrated = providers.where((p) => p['rated'] == false).toList();
    if (!loading &&
        error == null &&
        !uncertain &&
        providers.length == 1 &&
        providers.single['rated'] == true) {
      final saved = providers.single['rating'] as Map? ?? {};
      final rating = saved['rating'] as num? ?? 0;
      final comment = saved['comment'] is String
          ? (saved['comment'] as String).trim()
          : '';
      final score = Semantics(
        key: ValueKey('saved-rating-$rating'),
        label: 'Your rating: $rating / 5',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFBC00),
                  size: 18,
                ),
            ],
          ),
        ),
      );
      return Container(
        key: const ValueKey('booking-rating-section'),
        margin: const EdgeInsets.only(top: 6, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF2F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final stacked =
                bounds.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(12) > 17;
            final note = Text(
              comment,
              style: CustomerTypography.compact.copyWith(
                color: const Color(0xFF68718B),
              ),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2EAF3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_outlined,
                    size: 19,
                    color: Color(0xFF74849B),
                  ),
                ),
                const SizedBox(width: 10),
                if (stacked)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        score,
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          note,
                        ],
                      ],
                    ),
                  )
                else ...[
                  score,
                  if (comment.isNotEmpty) ...[
                    Container(
                      width: 1,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: const Color(0xFFD5DFEB),
                    ),
                    Expanded(child: note),
                  ],
                ],
              ],
            );
          },
        ),
      );
    }
    if (!loading &&
        error == null &&
        !uncertain &&
        data?['canRate'] == true &&
        data?['jobStatus'] == 'COMPLETED' &&
        unrated.length == 1 &&
        providers.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          key: const ValueKey('booking-add-review'),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE5F8F5), Color(0xFFCFF1EE)],
              ),
            ),
            child: InkWell(
              onTap: working ? null : () => _openProvider(unrated.single),
              child: CustomPaint(
                painter: const _ReviewBannerWaves(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add a Review',
                              style: CustomerTypography.card.copyWith(
                                color: const Color(0xFF101D42),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Share your experience with the provider.',
                              style: CustomerTypography.compact.copyWith(
                                color: CustomerColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const _ReviewStar(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      key: const ValueKey('booking-rating-section'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CustomerColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Rate your provider', style: CustomerTypography.section),
            const SizedBox(height: 6),
            for (final p in providers) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: CustomerColors.selection,
                  child: Icon(
                    Icons.person_outline,
                    color: CustomerColors.action,
                  ),
                ),
                title: Text(
                  p['displayName'] as String? ?? 'Your provider',
                  style: CustomerTypography.card,
                ),
                subtitle: Text(
                  p['rated'] == true
                      ? 'Your rating: ${(p['rating'] as Map?)?['rating']} / 5'
                      : 'Rate this service',
                  style: CustomerTypography.compact,
                ),
                trailing: Icon(
                  p['rated'] == true ? Icons.check_circle : Icons.chevron_right,
                  color: CustomerColors.action,
                ),
                onTap: p['rated'] == false && !loading && !working && !uncertain
                    ? () => _openProvider(p)
                    : null,
              ),
              if (p['rated'] == true &&
                  (p['rating'] as Map?)?['comment'] is String &&
                  (p['rating']['comment'] as String).isNotEmpty)
                Text(
                  p['rating']['comment'] as String,
                  style: CustomerTypography.body,
                ),
            ],
            if (error != null)
              Text(
                error!,
                style: CustomerTypography.compact.copyWith(
                  color: CustomerColors.error,
                ),
              ),
            if (!loading && (error != null || uncertain))
              TextButton(
                onPressed: working ? null : load,
                child: const Text('Check rating status'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStar extends StatelessWidget {
  const _ReviewStar();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 54,
      height: 48,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1200777D),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 30,
                color: Color(0xFFFFC400),
              ),
            ),
          ),
          const Positioned(
            right: 0,
            top: 10,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: Color(0xFF55BEB4),
            ),
          ),
          Positioned(
            left: 34,
            top: 0,
            child: Transform.rotate(
              angle: .3,
              child: Container(
                width: 3,
                height: 7,
                decoration: BoxDecoration(
                  color: CustomerColors.action,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Transform.rotate(
              angle: 1,
              child: Container(
                width: 3,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF8CCEB9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewBannerWaves extends CustomPainter {
  const _ReviewBannerWaves();
  @override
  void paint(Canvas canvas, Size size) {
    final wave = Path()
      ..moveTo(0, size.height * .74)
      ..cubicTo(
        size.width * .18,
        size.height * .78,
        size.width * .25,
        size.height * 1.15,
        size.width * .53,
        size.height,
      )
      ..cubicTo(
        size.width * .77,
        size.height * .95,
        size.width * .77,
        size.height * .50,
        size.width,
        size.height * .64,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave, Paint()..color = const Color(0x4485D9D0));
  }

  @override
  bool shouldRepaint(covariant _ReviewBannerWaves oldDelegate) => false;
}
