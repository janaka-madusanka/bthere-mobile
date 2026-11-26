import 'dart:async';

import 'package:flutter/material.dart';

class BannerSlide {
  const BannerSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.onTap,
  });
  final int id;
  final String title, imageUrl;
  final VoidCallback? onTap;
}

/// Image-only 2:1 artwork. Admin text is used as an accessibility label.
class BthereBannerCarousel extends StatefulWidget {
  const BthereBannerCarousel({
    super.key,
    required this.load,
    this.padding = const EdgeInsets.only(bottom: 15),
    this.aspectRatio = 2,
  });
  final Future<List<BannerSlide>> Function() load;
  final EdgeInsetsGeometry padding;
  final double aspectRatio;
  @override
  State<BthereBannerCarousel> createState() => _BannerState();
}

class _BannerState extends State<BthereBannerCarousel>
    with WidgetsBindingObserver {
  final _pages = PageController();
  List<BannerSlide> _slides = [];
  bool _loading = true, _busy = false;
  int _index = 0;
  Timer? _refresh, _autoSlide;
  bool _foreground = true;
  String? _firstReadyUrl;
  final _reportedImages = <String>{};

  void _imageReady(String url) {
    if (_reportedImages.contains(url)) return;
    _reportedImages.add(url);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _slides.isEmpty || _slides.first.imageUrl != url) return;
      _firstReadyUrl = url;
      _scheduleSlide();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSlide();
  }

  void _scheduleSlide() {
    _autoSlide?.cancel();
    if (_slides.isEmpty ||
        _firstReadyUrl != _slides.first.imageUrl ||
        !_foreground ||
        _slides.length < 2 ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _autoSlide = Timer(const Duration(seconds: 5), () async {
      if (!mounted || !_foreground) return;
      if (_pages.hasClients &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        await _pages.animateToPage(
          (_index + 1) % _slides.length,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
      if (mounted) _scheduleSlide();
    });
  }

  void _startRefresh() {
    _refresh?.cancel();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _refresh?.cancel();
    _autoSlide?.cancel();
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _load();
      _startRefresh();
      _scheduleSlide();
    }
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final slides = await widget.load();
      if (!mounted) return;
      final changed =
          slides.map((e) => e.id).join(',') !=
          _slides.map((e) => e.id).join(',');
      setState(() {
        _slides = slides;
        _loading = false;
        if (changed) {
          _index = 0;
          _firstReadyUrl = null;
          _reportedImages.clear();
        }
      });
      if (changed && _pages.hasClients) _pages.jumpToPage(0);
    } catch (_) {
      // Optional promotional content must never block Home or show stale offers.
      if (mounted) {
        setState(() {
          _loading = false;
          _slides = [];
        });
      }
    } finally {
      _busy = false;
      if (mounted) _scheduleSlide();
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _autoSlide?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _slides.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _loading
                  ? const _BannerSkeleton()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification &&
                            notification.dragDetails != null) {
                          _autoSlide?.cancel();
                        }
                        if (notification is ScrollEndNotification) {
                          _scheduleSlide();
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: _slides.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, i) {
                          final slide = _slides[i];
                          return Semantics(
                            label: slide.title,
                            image: true,
                            button: slide.onTap != null,
                            child: Material(
                              color: Colors.transparent,
                              elevation: 0,
                              surfaceTintColor: Colors.transparent,
                              child: InkWell(
                                onTap: slide.onTap,
                                child: SizedBox.expand(
                                  child: Image.network(
                                    slide.imageUrl,
                                    fit: BoxFit.cover,
                                    excludeFromSemantics: true,
                                    frameBuilder:
                                        (context, child, frame, synchronous) {
                                          if (synchronous || frame != null) {
                                            _imageReady(slide.imageUrl);
                                            return child;
                                          }
                                          return const _BannerSkeleton();
                                        },
                                    errorBuilder: (_, _, _) {
                                      // Skip a broken first image instead of trapping the carousel.
                                      _imageReady(slide.imageUrl);
                                      return const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Color(0xFF008F95),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
          if (_slides.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? const Color(0xFF008F95)
                          : const Color(0xFFD5E4E6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading banner',
    child: ExcludeSemantics(
      child: ColoredBox(
        color: const Color(0xFFF0F7F7),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(.55, 10),
                    const SizedBox(height: 12),
                    _bar(.95, 16),
                    const SizedBox(height: 8),
                    _bar(.75, 16),
                    const SizedBox(height: 16),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDDEBEC),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFDDEBEC),
                      shape: BoxShape.circle,
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
  Widget _bar(double width, double height) => FractionallySizedBox(
    widthFactor: width,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFDDEBEC),
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}
