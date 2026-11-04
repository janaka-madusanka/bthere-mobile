import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/customer_booking_controller.dart';
import '../domain/booking_card_checkout.dart';

final bookingCardCheckoutPresenterProvider =
    Provider<
      Future<void> Function(
        BuildContext,
        BookingCardCheckout,
        CustomerBookingController,
      )
    >(
      (ref) =>
          (context, checkout, controller) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BookingCardCheckoutPage(
                checkout: checkout,
                controller: controller,
              ),
            ),
          ),
    );

class BookingCardCheckoutPage extends StatefulWidget {
  const BookingCardCheckoutPage({
    super.key,
    required this.checkout,
    required this.controller,
  });
  final BookingCardCheckout checkout;
  final CustomerBookingController controller;
  @override
  State<BookingCardCheckoutPage> createState() =>
      _BookingCardCheckoutPageState();
}

class _BookingCardCheckoutPageState extends State<BookingCardCheckoutPage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  Timer? _timer;
  bool _closing = false, _failed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_changed);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame && widget.checkout.isReturn(uri)) {
              _close();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _failed = true);
            }
          },
        ),
      );
    // Android's WebView POST sets the form content type itself. No auth token or
    // locally constructed signature is forwarded to the gateway.
    _web
        .loadRequest(
          widget.checkout.action,
          method: LoadRequestMethod.post,
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: widget.checkout.body,
        )
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted ||
        _closing ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    await widget.controller.refreshCreatedRequest(background: true);
  }

  void _changed() {
    final c = widget.controller;
    if (!c.alive ||
        c.paymentOutcome != null ||
        {'CANCELLED', 'EXPIRED', 'UNMATCHED'}.contains(c.created?['status'])) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
  }

  void _close() {
    if (!mounted || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Secure card payment')),
    body: Column(
      children: [
        if (_progress < 100 && !_failed)
          LinearProgressIndicator(value: _progress / 100),
        if (_failed)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Checkout could not be loaded. Go back to check your payment status before trying again.',
            ),
          ),
        Expanded(child: WebViewWidget(controller: _web)),
      ],
    ),
  );
}
