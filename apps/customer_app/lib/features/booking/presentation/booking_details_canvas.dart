import '../../../app/customer_theme.dart';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';

import '../../discovery/presentation/customer_discovery_style.dart';
import '../../discovery/domain/customer_discovery.dart';
import '../application/customer_booking_controller.dart';
import 'booking_location_picker.dart';
import 'booking_service_dropdown.dart';

/// Map and editable schema-driven details share the same booking draft.
class BookingDetailsCanvas extends StatefulWidget {
  const BookingDetailsCanvas({
    super.key,
    required this.controller,
    required this.onBack,
    required this.children,
    required this.onOptionChanged,
    this.panelTitle = 'Location and time',
    this.keyboardOpen = false,
  });
  final CustomerBookingController controller;
  final VoidCallback onBack;
  final List<Widget> children;
  final ValueChanged<CustomerServiceOption> onOptionChanged;
  final String panelTitle;
  final bool keyboardOpen;
  @override
  State<BookingDetailsCanvas> createState() => _BookingDetailsCanvasState();
}

class _BookingDetailsCanvasState extends State<BookingDetailsCanvas> {
  final _sheet = DraggableScrollableController();
  ScrollController? _scroll;
  String? _error;
  final _bodyKey = GlobalKey();
  final _footerKey = GlobalKey();
  double _maxSize = .94;
  bool _measurementScheduled = false;
  bool _keyboardVisible = false;
  double? _sizeBeforeKeyboard;
  double _keyboardHeight = 0;
  double _normalViewportHeight = 0;
  bool _userAdjustedSheet = false;
  bool _sheetRebuildScheduled = false;

  void _sheetChanged() {
    if (_sheetRebuildScheduled) return;
    _sheetRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetRebuildScheduled = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _revealFocusedField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_keyboardVisible) return;
      final focused = FocusManager.instance.primaryFocus?.context;
      final body = _bodyKey.currentContext;
      if (focused == null || body == null || !focused.mounted) return;
      var insideForm = false;
      focused.visitAncestorElements((element) {
        if (element == body) insideForm = true;
        return !insideForm;
      });
      if (insideForm) {
        final editable = focused.findAncestorStateOfType<EditableTextState>();
        final target = (editable?.context ?? focused).findRenderObject();
        if (target == null || !(_scroll?.hasClients ?? false)) return;
        _scroll!.position.ensureVisible(
          target,
          duration: const Duration(milliseconds: 160),
          alignment: .5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
    // Focus/keyboard notifications can arrive after the final layout frame.
    // Ensure the visibility callback actually gets a frame in that case.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncKeyboard(bool visible, double height, double expandedSize) {
    if (visible == _keyboardVisible &&
        (!visible || (height - _keyboardHeight).abs() < 1)) {
      return;
    }
    if (visible && !_keyboardVisible) {
      _sizeBeforeKeyboard = _sheet.isAttached ? _sheet.size : _initialSize;
    }
    _keyboardVisible = visible;
    _keyboardHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheet.isAttached || visible != _keyboardVisible) return;
      _sheet.jumpTo(
        visible
            ? expandedSize
            : (_sizeBeforeKeyboard ?? _initialSize).clamp(_minSize, _maxSize),
      );
      if (visible) _revealFocusedField();
    });
  }

  void _measureContent(double availableHeight) {
    if (_measurementScheduled || _keyboardVisible) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted || _keyboardVisible || availableHeight <= 0) {
        return;
      }
      final body = _bodyKey.currentContext?.size;
      final footer = _footerKey.currentContext?.size;
      if (body == null || footer == null) return;
      // Include scroll padding and the SafeArea, but no unused viewport space.
      final height =
          body.height +
          18 +
          8 + // Keep the last payment row clear of the pinned footer.
          footer.height +
          MediaQuery.paddingOf(context).bottom;
      final badgeHeight =
          (MediaQuery.textScalerOf(context).scale(12) * 2.6).clamp(40, 100) +
          16;
      final cap = widget.panelTitle == 'Review your booking'
          ? (1 - MediaQuery.paddingOf(context).top / availableHeight).clamp(
              _minSize,
              1.0,
            )
          : widget.controller.availabilityStatusLabel == null
          ? .94
          : (1 -
                    (MediaQuery.paddingOf(context).top +
                            68 +
                            badgeHeight +
                            12) /
                        availableHeight)
                .clamp(_minSize, .94);
      final maximum = (height / availableHeight).clamp(_minSize, cap);
      final openReview =
          widget.panelTitle == 'Review your booking' && !_userAdjustedSheet;
      if ((maximum - _maxSize).abs() < .001) {
        if (openReview && _sheet.isAttached && _sheet.size < maximum - .001) {
          _sheet.jumpTo(maximum);
        }
        return;
      }
      final wasExpanded =
          _sheet.isAttached && (_sheet.size - _maxSize).abs() < .015;
      setState(() => _maxSize = maximum);
      // Apply the extent only after the next layout receives the new maximum.
      // An immediate jump here is clamped against the previous sheet limits.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _keyboardVisible || !_sheet.isAttached) return;
        if (openReview || wasExpanded || _sheet.size > _maxSize) {
          _sheet.jumpTo(_maxSize);
        }
      });
    });
  }

  double get _minSize => widget.panelTitle == 'Service details' ? .25 : .35;
  double get _initialSize => _maxSize;
  @override
  void initState() {
    super.initState();
    _sheet.addListener(_sheetChanged);
    _error = widget.controller.error;
    widget.controller.addListener(_feedback);
    FocusManager.instance.addListener(_revealFocusedField);
  }

  void _feedback() {
    final error =
        widget.controller.error ?? widget.controller.availabilityNotice;
    if (error != null && error != _error) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        FocusScope.of(context).unfocus();
        if (_sheet.isAttached) {
          await _sheet.animateTo(
            _maxSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        if (mounted && (_scroll?.hasClients ?? false)) _scroll!.jumpTo(0);
      });
    }
    _error = error;
  }

  @override
  void didUpdateWidget(BookingDetailsCanvas old) {
    super.didUpdateWidget(old);
    if (old.panelTitle != widget.panelTitle) {
      _userAdjustedSheet = false;
      _maxSize = .94;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_sheet.isAttached) {
          _sheet.jumpTo(_initialSize.clamp(_minSize, _maxSize));
        }
        if (_scroll?.hasClients ?? false) _scroll!.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _sheet.removeListener(_sheetChanged);
    FocusManager.instance.removeListener(_revealFocusedField);
    widget.controller.removeListener(_feedback);
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    bool inlineServiceError(String key) =>
        key.startsWith('service-field-') ||
        {'Service address', 'Destination address', 'Notes'}.contains(key);
    final hasServiceHints = c.fieldErrors.keys.any(inlineServiceError);
    final physical = c.mode != 'ONLINE';
    final icon = c.context!.option['icon'];
    final iconUrl = icon is Map
        ? safeImageUrl(icon['url'])
        : safeImageUrl(c.context!.option['iconUrl']);
    return LayoutBuilder(
      builder: (context, bounds) {
        final keyboardOpen =
            widget.keyboardOpen || MediaQuery.viewInsetsOf(context).bottom > 0;
        const keyboardSize = 1.0;
        if (!keyboardOpen) _normalViewportHeight = bounds.maxHeight;
        final minimum = keyboardOpen ? keyboardSize : _minSize;
        final maximum = keyboardOpen ? keyboardSize : _maxSize;
        final inlineFooter = keyboardOpen && bounds.maxHeight < 300;
        _syncKeyboard(keyboardOpen, bounds.maxHeight, keyboardSize);
        _measureContent(bounds.maxHeight);
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: const Color(0xFFE9F6F4))),
            if (physical)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Builder(
                  builder: (context) => BookingLocationPicker(
                    key: const ValueKey('booking-location'),
                    animateLocationChanges: c.stage == BookingStage.details,
                    filterPulseKey: c.stage == BookingStage.details
                        ? '${c.point?.latitude},${c.point?.longitude}|${c.radius}|'
                              '${c.start}|${c.end}|${c.mode}|'
                              '${c.destination?.latitude},${c.destination?.longitude}|'
                              '${c.languages}|${c.skills}|${c.providerFilters}'
                        : null,
                    point: c.point,
                    onChanged: (point) => c.edit(() {
                      c.point = point;
                      c.address = '';
                    }),
                    onAddressChanged: (address) =>
                        c.edit(() => c.address = address),
                    radiusKm: c.radius.isFinite && c.radius > 0 ? c.radius : 10,
                    candidates: c.availableCandidates,
                    enabled:
                        !c.busy && widget.panelTitle != 'Review your booking',
                    showRecenter: widget.panelTitle == 'Review your booking',
                    showControls: !keyboardOpen,
                    mapOnly: true,
                    autoLocate: true,
                    height: keyboardOpen
                        ? _normalViewportHeight *
                              (1 - (_sizeBeforeKeyboard ?? _maxSize))
                        : bounds.maxHeight *
                              (1 -
                                  (_sheet.isAttached
                                      ? _sheet.size
                                      : _initialSize.clamp(
                                          _minSize,
                                          _maxSize,
                                        ))),
                  ),
                ),
              ),
            if (!physical)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Icon(
                  Icons.videocam_outlined,
                  size: 100,
                  color: catalogTeal,
                ),
              ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: c.busy ? null : widget.onBack,
                      icon: const Icon(Icons.arrow_back, color: catalogInk),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        elevation: 3,
                        child: BookingServiceDropdown(
                          controller: c,
                          onChanged: widget.onOptionChanged,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CatalogIcon(
                                  appearance: const ServiceAppearance(
                                    catalogTeal,
                                    Icons.category_outlined,
                                  ),
                                  url: iconUrl,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    c.context!.name,
                                    style: const TextStyle(
                                      color: catalogInk,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: catalogInk,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!keyboardOpen)
              if (c.availabilityStatusLabel case final label?)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 68,
                  right: 16,
                  child: Material(
                    color: Colors.white,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: bounds.maxWidth - 32,
                      ),
                      child: Padding(
                        key: const ValueKey('booking-availability-count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.checkingAvailability)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(
                                Icons.people_alt_outlined,
                                color: catalogTeal,
                                size: 20,
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                maxLines: c.availabilityInputHint != null
                                    ? 3
                                    : 2,
                                style: const TextStyle(
                                  color: catalogInk,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (!c.allowed)
                              TextButton(
                                onPressed: c.busy ? null : c.openRequirements,
                                child: const Text('View details'),
                              ),
                            if (c.allowed && c.availabilityError != null)
                              IconButton(
                                tooltip: 'Retry provider availability',
                                onPressed: c.retryAvailability,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: catalogTeal,
                                ),
                              ),
                            if (!c.checkingAvailability &&
                                c.availabilityError == null &&
                                c.hasMoreAvailableProviders)
                              IconButton(
                                tooltip: 'Show more available providers',
                                onPressed: c.busy
                                    ? null
                                    : c.loadMoreAvailableProviders,
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                  color: catalogTeal,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) _userAdjustedSheet = true;
                return false;
              },
              child: DraggableScrollableSheet(
                key: const ValueKey('booking-details-sheet'),
                controller: _sheet,
                initialChildSize: _initialSize.clamp(minimum, maximum),
                minChildSize: minimum,
                maxChildSize: maximum,
                snap: !keyboardOpen,
                snapSizes: keyboardOpen
                    ? null
                    : [if (_initialSize < _maxSize) _initialSize, _maxSize],
                builder: (context, scroll) {
                  _scroll = scroll;
                  return Material(
                    color: catalogPaper,
                    elevation: 12,
                    borderRadius: keyboardOpen
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(top: Radius.circular(30)),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: keyboardOpen,
                      child: Column(
                        children: [
                          Expanded(
                            key: const ValueKey('booking-form-scroll-area'),
                            child: SingleChildScrollView(
                              controller: scroll,
                              keyboardDismissBehavior: keyboardOpen
                                  ? ScrollViewKeyboardDismissBehavior.manual
                                  : ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(18, 10, 18, 8),
                              child:
                                  NotificationListener<
                                    SizeChangedLayoutNotification
                                  >(
                                    onNotification: (_) {
                                      _measureContent(bounds.maxHeight);
                                      return false;
                                    },
                                    child: SizeChangedLayoutNotifier(
                                      child: Column(
                                        key: _bodyKey,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (!keyboardOpen)
                                            Center(
                                              child: Container(
                                                width: 42,
                                                height: 5,
                                                margin: const EdgeInsets.only(
                                                  bottom: 16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          if (c.availabilityNotice
                                              case final notice?)
                                            Container(
                                              key: const ValueKey(
                                                'booking-availability-notice',
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: catalogTeal.withValues(
                                                  alpha: .06,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: catalogTeal.withValues(
                                                    alpha: .14,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .travel_explore_rounded,
                                                    color: catalogTeal,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          notice,
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    catalogInk,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        const Text(
                                                          'Try a different time, widen your search area or adjust your filters.',
                                                          style: TextStyle(
                                                            color: catalogMuted,
                                                            fontSize: 12,
                                                            height: 1.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (c.error != null &&
                                              (c.fieldErrors.isEmpty ||
                                                  (widget.panelTitle ==
                                                          'Service details' &&
                                                      !hasServiceHints)))
                                            BThereInlineError(c.error!),
                                          if (widget.panelTitle ==
                                              'Service details')
                                            for (final error
                                                in c.fieldErrors.entries.where(
                                                  (entry) =>
                                                      !inlineServiceError(
                                                        entry.key,
                                                      ),
                                                ))
                                              Text(
                                                '${error.key}: ${error.value}',
                                                style: const TextStyle(
                                                  color: CustomerColors.error,
                                                ),
                                              ),
                                          if (c.busy)
                                            const LinearProgressIndicator(),
                                          Column(
                                            key: const ValueKey(
                                              'booking-form-content',
                                            ),
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: widget.children
                                                .take(
                                                  widget.children.length - 1,
                                                )
                                                .toList(),
                                          ),
                                          if (inlineFooter) ...[
                                            const SizedBox(height: 12),
                                            widget.children.last,
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          if (!inlineFooter)
                            Padding(
                              key: _footerKey,
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: widget.children.last,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
