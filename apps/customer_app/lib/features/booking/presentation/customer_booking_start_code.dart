import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/customer_providers.dart';
import '../../../app/customer_theme.dart';
import '../../auth/application/customer_auth_controller.dart';
import '../application/customer_booking_controller.dart';
import '../application/customer_booking_history.dart';
import '../application/customer_booking_start_controller.dart';

class CustomerBookingStartCode extends ConsumerStatefulWidget {
  const CustomerBookingStartCode({
    super.key,
    required this.booking,
    this.scheduledStart,
  });
  final Map<String, dynamic> booking;
  final DateTime? scheduledStart;
  @override
  ConsumerState<CustomerBookingStartCode> createState() =>
      _CustomerBookingStartCodeState();
}

class _CustomerBookingStartCodeState
    extends ConsumerState<CustomerBookingStartCode>
    with WidgetsBindingObserver {
  late final CustomerBookingStartController controller;
  Timer? timer;
  bool _copying = false;
  bool? _lastWindow;
  DateTime? _nextWindowCheck;
  bool get withinWindow => widget.scheduledStart == null
      ? controller.windowAvailable == true
      : !ref
            .read(customerClockProvider)()
            .isBefore(
              widget.scheduledStart!.subtract(const Duration(minutes: 30)),
            );

  void _checkUnknownWindow({bool force = false}) {
    if (!mounted ||
        widget.scheduledStart != null ||
        !controller.eligible ||
        ModalRoute.of(context)?.isCurrent == false ||
        !{
          null,
          AppLifecycleState.resumed,
        }.contains(WidgetsBinding.instance.lifecycleState)) {
      return;
    }
    final now = ref.read(customerClockProvider)();
    if (!force && _nextWindowCheck?.isAfter(now) == true) return;
    _nextWindowCheck = now.add(const Duration(minutes: 1));
    unawaited(controller.checkWindow());
  }

  Future<void> _copyCode() async {
    final value = controller.code;
    if (_copying || !controller.alive || value == null) return;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted && controller.alive && controller.code == value) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Start code copied.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to copy the start code.')),
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Widget _revealedCode(String code) => Container(
    key: const ValueKey('booking-start-code-section'),
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00AAA9), Color(0xFF00777D), Color(0xFF009E9B)],
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final copy = IconButton(
          key: const ValueKey('booking-start-code-copy'),
          tooltip: 'Copy start code',
          onPressed: _copying ? null : _copyCode,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFE5FAFA),
            foregroundColor: CustomerColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.copy_outlined, size: 20),
        );
        final digits = Semantics(
          label: 'Service start code ${code.split('').join(' ')}',
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var index = 0; index < 4; index++) ...[
                  if (index > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        code[index],
                        textAlign: TextAlign.center,
                        style: CustomerTypography.screen.copyWith(
                          color: CustomerColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Service Start Code',
                maxLines: 1,
                style: CustomerTypography.compactStrong.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Tooltip(
              message: 'Hide code',
              child: TextButton.icon(
                key: const ValueKey('booking-start-code-action'),
                onPressed: controller.hide,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, 48),
                  textStyle: CustomerTypography.compactStrong,
                ),
                icon: const Icon(Icons.visibility_off_outlined, size: 16),
                label: const Text('Hide code'),
              ),
            ),
          ],
        );
        if (bounds.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(12) > 16) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Expanded(child: title)]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: digits),
                  const SizedBox(width: 10),
                  copy,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            Container(
              width: 1,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white.withValues(alpha: .3),
            ),
            Expanded(flex: 2, child: digits),
            const SizedBox(width: 8),
            copy,
          ],
        );
      },
    ),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = CustomerBookingStartController(
      ref.read(customerBookingRepositoryProvider),
      ref.read(customerAuthControllerProvider),
      ref.read(customerClockProvider),
      widget.booking,
      onBookingChanged: () {
        final owner = ref.read(customerAuthControllerProvider).user?.id;
        if (mounted && owner != null) {
          ref.invalidate(customerBookingHistoryProvider(owner));
        }
      },
    );
    controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUnknownWindow());
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          !controller.alive ||
          ModalRoute.of(context)?.isCurrent == false ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.inactive) {
        return;
      }
      _checkUnknownWindow();
      // The details progress card owns foreground status polling. This timer
      // only hides an expired revealed code; avoid duplicate history requests.
      if (controller.expiresAt != null || _lastWindow != withinWindow) {
        _lastWindow = withinWindow;
        setState(() {});
      }
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CustomerBookingStartCode old) {
    super.didUpdateWidget(old);
    controller.updateBooking(widget.booking);
    if (old.scheduledStart != widget.scheduledStart ||
        old.booking['startDatetime'] != widget.booking['startDatetime'] ||
        old.booking['status'] != widget.booking['status']) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkUnknownWindow(force: true),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      controller.hide();
    } else {
      _checkUnknownWindow(force: true);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.eligible || !withinWindow) return const SizedBox.shrink();
    final code = c.code;
    if (code != null) return _revealedCode(code);
    final action = OutlinedButton.icon(
      key: const ValueKey('booking-start-code-action'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: CustomerColors.action,
        minimumSize: const Size(48, 44),
        textStyle: CustomerTypography.compactStrong.copyWith(
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      onPressed: c.busy ? null : c.load,
      icon: c.busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.visibility_outlined, size: 18),
      label: Text(c.busy ? 'Loading code…' : 'Show code'),
    );
    return Container(
      key: const ValueKey('booking-start-code-section'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00AAA9), Color(0xFF00777D), Color(0xFF009E9B)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, bounds) {
              final description = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service start code',
                    style: CustomerTypography.card.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share at service start.',
                    style: CustomerTypography.compact.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
              final title = Row(
                children: [
                  Container(
                    width: 42,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.white.withValues(alpha: .3),
                  ),
                  Expanded(child: description),
                ],
              );
              if (bounds.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(12) > 16) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  action,
                ],
              );
            },
          ),
          if (c.expired || c.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                c.error ??
                    'This start code has expired. Check availability again.',
                style: CustomerTypography.compact.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
