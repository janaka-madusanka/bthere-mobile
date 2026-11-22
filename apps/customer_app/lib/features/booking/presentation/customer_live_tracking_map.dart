import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/customer_theme.dart';
import '../../../app/customer_providers.dart';
import '../data/customer_ride_route.dart';
import '../domain/booking_tracking.dart';
import 'customer_booking_map.dart';
import 'customer_map_marker_icons.dart';

class CustomerLiveTrackingMap extends ConsumerStatefulWidget {
  const CustomerLiveTrackingMap({
    super.key,
    required this.tracking,
    this.compact = false,
  });
  final BookingTrackingStatus tracking;
  final bool compact;
  @override
  ConsumerState<CustomerLiveTrackingMap> createState() =>
      _CustomerLiveTrackingMapState();
}

class _CustomerLiveTrackingMapState
    extends ConsumerState<CustomerLiveTrackingMap> {
  GoogleMapController? map;
  bool follow = true;
  RideEndpoints? routeEndpoints;
  DateTime? routeRequestedAt;
  void updateRoute() {
    final tracking = widget.tracking;
    final now = ref.read(customerClockProvider)().toUtc();
    final provider = tracking.providers.length == 1
        ? tracking.providers.single
        : null;
    final origin = provider?.point, target = tracking.target;
    if (!widget.compact ||
        !{'EN_ROUTE', 'IN_TRIP'}.contains(tracking.status) ||
        origin == null ||
        target == null ||
        provider!.stale(now, tracking.staleSeconds)) {
      routeEndpoints = null;
      return;
    }
    final next = (
      origin.latitude,
      origin.longitude,
      target.latitude,
      target.longitude,
    );
    final old = routeEndpoints;
    final targetChanged = old == null || old.$3 != next.$3 || old.$4 != next.$4;
    final moved =
        old == null ||
        (old.$1 - next.$1).abs() + (old.$2 - next.$2).abs() >= .002;
    if (targetChanged ||
        moved &&
            (routeRequestedAt == null ||
                now.difference(routeRequestedAt!).inSeconds >= 60)) {
      routeEndpoints = next;
      routeRequestedAt = now;
    }
  }

  final icons = <String, BitmapDescriptor>{};
  final attempted = <String>{};
  List<LatLng> get points => [
    if (widget.tracking.target case final p?) LatLng(p.latitude, p.longitude),
    for (final provider in widget.tracking.providers)
      if (provider.point case final p?) LatLng(p.latitude, p.longitude),
  ];
  void loadIcons() {
    for (final provider in widget.tracking.providers) {
      final url = provider.marker;
      if (url == null || !attempted.add(url)) continue;
      ref.read(customerMarkerIconLoaderProvider)(url).then((icon) {
        if (mounted && icon != null) setState(() => icons[url] = icon);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadIcons();
    updateRoute();
  }

  @override
  void didUpdateWidget(CustomerLiveTrackingMap old) {
    super.didUpdateWidget(old);
    loadIcons();
    updateRoute();
    String geometry(BookingTrackingStatus value) => [
      value.target,
      ...value.providers.map((p) => p.point),
    ].map((p) => '${p?.latitude}/${p?.longitude}').join('|');
    if (follow && geometry(old.tracking) != geometry(widget.tracking)) fit();
  }

  Future<void> fit() async {
    final current = map, all = points;
    if (current == null || all.isEmpty || !mounted) return;
    try {
      if (all.length == 1 || all.every((p) => p == all.first)) {
        await current.animateCamera(CameraUpdate.newLatLngZoom(all.first, 15));
      } else {
        final bounds = LatLngBounds(
          southwest: LatLng(
            all.map((p) => p.latitude).reduce(math.min),
            all.map((p) => p.longitude).reduce(math.min),
          ),
          northeast: LatLng(
            all.map((p) => p.latitude).reduce(math.max),
            all.map((p) => p.longitude).reduce(math.max),
          ),
        );
        await current.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
      }
    } catch (_) {
      /* Keep textual journey information usable without native map. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = points;
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Waiting for the first shared location…',
          style: CustomerTypography.compact,
        ),
      );
    }
    final tracking = widget.tracking;
    // Reuse the existing Routes integration. A failed route leaves honest pins,
    // never a fabricated straight line. Fare/ETA remain backend-owned.
    final route = routeEndpoints == null
        ? null
        : ref.watch(customerRideRouteProvider(routeEndpoints!));
    final geometry = route?.asData?.value ?? const [];
    final markers = <Marker>{
      if (tracking.target case final p?)
        Marker(
          markerId: const MarkerId('tracking-target'),
          position: LatLng(p.latitude, p.longitude),
          infoWindow: InfoWindow(
            title:
                '${(tracking.payload['target'] as Map?)?['label'] ?? 'Service location'}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      for (final p in tracking.providers)
        if (p.point case final point?)
          Marker(
            markerId: MarkerId('tracking-provider-${p.id}'),
            position: LatLng(point.latitude, point.longitude),
            infoWindow: InfoWindow(title: p.name),
            icon:
                icons[p.marker] ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            rotation: p.heading,
            flat: true,
          ),
    };
    return Column(
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Listener(
            onPointerDown: (_) => follow = false,
            child: SizedBox(
              height: widget.compact ? 174 : 280,
              child: ref.watch(customerMapBuilderProvider)(
                CustomerMapState(
                  camera: CameraPosition(target: all.first, zoom: 13),
                  onCreated: (value) {
                    map = value;
                    fit();
                  },
                  onSelect: null,
                  markers: markers,
                  polylines: {
                    if (geometry.length > 1)
                      Polyline(
                        polylineId: const PolylineId('provider-driving-route'),
                        points: geometry
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: const Color(0xFF188CE5),
                        width: 5,
                      ),
                  },
                  circles: const {},
                ),
              ),
            ),
          ),
        ),
        if (!widget.compact)
          TextButton.icon(
            onPressed: () {
              follow = true;
              fit();
            },
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Show all locations'),
          ),
      ],
    );
  }
}
