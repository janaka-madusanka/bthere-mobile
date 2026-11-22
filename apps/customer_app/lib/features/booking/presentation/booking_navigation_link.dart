import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final customerNavigationLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

class BookingNavigationLink extends ConsumerStatefulWidget {
  const BookingNavigationLink({super.key, required this.uri});
  final Uri uri;
  @override
  ConsumerState<BookingNavigationLink> createState() =>
      _BookingNavigationLinkState();
}

class _BookingNavigationLinkState extends ConsumerState<BookingNavigationLink> {
  bool opening = false;
  Future<void> open() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final result = await ref.read(customerNavigationLauncherProvider)(
        widget.uri,
      );
      if (!result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Maps could not be opened. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Directions are currently unavailable.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('booking-open-navigation'),
    onPressed: opening ? null : open,
    icon: const Icon(Icons.directions_outlined),
    label: Text(opening ? 'Opening…' : 'Open directions in Google Maps'),
  );
}
