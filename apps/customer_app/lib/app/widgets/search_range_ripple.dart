import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Reusable, pointer-transparent ripple. The caller supplies projected geometry;
/// this component owns playback, idle gaps, visibility and accessibility.
class SearchRangeRipple extends StatefulWidget {
  const SearchRangeRipple({
    super.key,
    required this.trigger,
    required this.center,
    required this.radius,
    this.east,
    this.north,
    this.paused = false,
    this.repeat = false,
    this.repeatDelay = const Duration(milliseconds: 1400),
    this.duration = const Duration(milliseconds: 2800),
  });
  final Object? trigger;
  final Offset? center, east, north;
  final double? radius;
  final bool paused;
  final bool repeat;
  final Duration repeatDelay;
  final Duration duration;

  @override
  State<SearchRangeRipple> createState() => _SearchRangeRippleState();
}

class _SearchRangeRippleState extends State<SearchRangeRipple>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation;
  Timer? _repeatTimer;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: widget.duration);
    _animation.addStatusListener(_statusChanged);
    WidgetsBinding.instance.addObserver(this);
    _pending = widget.repeat;
  }

  bool get _canPlay {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return widget.trigger != null &&
        !widget.paused &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        ModalRoute.of(context)?.isCurrent != false &&
        widget.center != null &&
        widget.radius != null &&
        widget.radius!.isFinite &&
        widget.radius! > 1;
  }

  void _statusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !widget.repeat || !_canPlay) {
      return;
    }
    _repeatTimer?.cancel();
    // No ticker frames, map projection or network work during the idle gap.
    _repeatTimer = Timer(widget.repeatDelay, () {
      _repeatTimer = null;
      if (!mounted) return;
      _pending = true;
      _playWhenReady();
    });
  }

  void _playWhenReady() {
    if (widget.trigger == null || MediaQuery.disableAnimationsOf(context)) {
      _pending = false;
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _animation.reset();
    } else if (!_canPlay) {
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _pending = _pending || widget.repeat || _animation.isAnimating;
      _animation.reset();
    } else if (_pending) {
      _pending = false;
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _animation.forward(from: 0);
    } else if (widget.repeat &&
        !_animation.isAnimating &&
        _repeatTimer == null) {
      _pending = true;
      _playWhenReady();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playWhenReady();
  }

  @override
  void didUpdateWidget(SearchRangeRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.duration;
    if (oldWidget.trigger != widget.trigger ||
        oldWidget.repeat != widget.repeat) {
      _pending = widget.trigger != null;
      _repeatTimer?.cancel();
      _repeatTimer = null;
      _animation.reset();
    }
    if (widget.center == null || widget.paused) {
      // Never consume a new pulse against stale or unavailable geometry.
      if (_animation.isAnimating) {
        _pending = true;
        _animation.reset();
      }
    }
    _playWhenReady();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _playWhenReady();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('search-range-ripple-paint'),
        painter: SearchRangeRipplePainter(
          animation: _animation,
          center: widget.center,
          radius: widget.radius,
          east: widget.east,
          north: widget.north,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repeatTimer?.cancel();
    _animation.removeStatusListener(_statusChanged);
    _animation.dispose();
    super.dispose();
  }
}

/// Paint-only water ripples: the native map and search geometry stay unchanged.
class SearchRangeRipplePainter extends CustomPainter {
  SearchRangeRipplePainter({
    required this.animation,
    this.center,
    this.radius,
    this.east,
    this.north,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Offset? center;
  final double? radius;
  final Offset? east;
  final Offset? north;

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value <= 0 || animation.value >= 1) return;
    // Never guess the map center while native projection is unavailable.
    final origin = center;
    final extent = radius;
    if (origin == null || extent == null) return;
    if (extent <= 0 || !extent.isFinite) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    if (east case final x?) {
      if (north case final y?) {
        canvas.transform(
          Float64List.fromList([
            x.dx / extent,
            x.dy / extent,
            0,
            0,
            y.dx / extent,
            y.dy / extent,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        );
      }
    }
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: extent - 1)),
    );
    // A soft fill keeps map labels readable; a defined teal crest makes each
    // emission visible against both light roads and darker map terrain.
    for (var wave = 0; wave < 3; wave++) {
      final travel = (animation.value - wave * .20) / .60;
      if (travel <= 0 || travel >= 1) continue;
      final entry = (travel / .06).clamp(0.0, 1.0);
      final visibility = (1 - travel) * Curves.easeOut.transform(entry);
      final waveRadius = extent * (.01 + .99 * travel);
      const teal = Color(0xFF008F95);
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                teal.withValues(alpha: .025 * visibility),
                teal.withValues(alpha: .07 * visibility),
                teal.withValues(alpha: .18 * visibility),
              ],
              stops: const [0, .72, 1],
            ).createShader(
              Rect.fromCircle(center: Offset.zero, radius: waveRadius),
            );
      canvas.drawCircle(Offset.zero, waveRadius, paint);
      canvas.drawCircle(
        Offset.zero,
        waveRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = teal.withValues(alpha: .65 * visibility),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SearchRangeRipplePainter oldDelegate) =>
      animation != oldDelegate.animation ||
      center != oldDelegate.center ||
      radius != oldDelegate.radius ||
      east != oldDelegate.east ||
      north != oldDelegate.north;
}
