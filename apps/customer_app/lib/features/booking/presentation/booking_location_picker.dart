import '../../../app/customer_theme.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../discovery/presentation/customer_discovery_style.dart';
import '../domain/booking_models.dart';
import 'customer_booking_map.dart';
import 'customer_map_marker_icons.dart';
import 'provider_map_pins.dart';
import '../data/customer_location_address.dart';

final customerDeviceLocationProvider = Provider<Future<GeoPoint> Function()>(
  (ref) => () async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const BookingProblem(
        'Location services are off. Tap the map to choose a pin instead.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const BookingProblem(
        'Location permission is unavailable. Tap the map to choose a pin instead.',
      );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return GeoPoint(p.latitude, p.longitude);
  },
);

class BookingLocationPicker extends ConsumerStatefulWidget {
  const BookingLocationPicker({
    super.key,
    required this.point,
    required this.onChanged,
    this.radiusKm = 5,
    this.candidates = const [],
    this.enabled = true,
    this.label = 'Service location',
    this.mapOnly = false,
    this.height = 250,
    this.autoLocate = false,
    this.onAddressChanged,
    this.showRecenter = false,
    this.onProviderSelected,
    this.preferProviderPhotos = false,
  });
  final GeoPoint? point;
  final ValueChanged<GeoPoint> onChanged;
  final double radiusKm;
  final List<ProviderCandidate> candidates;
  final bool enabled;
  final String label;
  final bool mapOnly;
  final double height;
  final bool autoLocate;
  final ValueChanged<String>? onAddressChanged;
  final bool showRecenter;
  final ValueChanged<ProviderCandidate>? onProviderSelected;
  final bool preferProviderPhotos;
  @override
  ConsumerState<BookingLocationPicker> createState() =>
      _BookingLocationPickerState();
}

class _BookingLocationPickerState extends ConsumerState<BookingLocationPicker> {
  GoogleMapController? _map;
  Timer? _cameraTimer;
  bool _locating = false;
  final _icons = <String, BitmapDescriptor>{};
  final _loadingIcons = <String>{};
  String? _error;
  int _selection = 0;
  GeoPoint? _emittedPoint;
  @override
  void initState() {
    super.initState();
    if (widget.autoLocate && widget.enabled && widget.point == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.point == null && widget.enabled) {
          _gps(initial: true);
        }
      });
    }
  }

  double get _radiusZoom {
    final size = MediaQuery.sizeOf(context);
    final viewport = math.min(size.width, widget.height).clamp(64, 2000) * .8;
    final latitude = widget.point?.latitude ?? 7.8731;
    final metresPerPixel =
        156543.03392 * math.cos(latitude * math.pi / 180).abs().clamp(.01, 1);
    return (math.log(
              metresPerPixel *
                  viewport /
                  (widget.radiusKm.clamp(.1, 500) * 2000),
            ) /
            math.ln2)
        .clamp(2, 17);
  }

  @override
  void didUpdateWidget(BookingLocationPicker old) {
    super.didUpdateWidget(old);
    if (old.point != widget.point ||
        old.radiusKm != widget.radiusKm ||
        old.height != widget.height ||
        !listEquals(old.candidates, widget.candidates)) {
      if (old.point != widget.point) {
        if (_emittedPoint?.latitude != widget.point?.latitude ||
            _emittedPoint?.longitude != widget.point?.longitude) {
          _selection++;
        }
        _emittedPoint = null;
      }
      if (widget.point case final point?) {
        if (_map != null) {
          _cameraTimer?.cancel();
          _cameraTimer = Timer(const Duration(milliseconds: 120), () {
            if (mounted) _moveCamera(point);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _cameraTimer?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _choose(GeoPoint p) {
    if (!widget.enabled) return;
    _selection++;
    _emittedPoint = p;
    setState(() => _error = null);
    widget.onChanged(p);
    if (widget.onAddressChanged != null) _resolveAddress(p, _selection);
  }

  Future<void> _resolveAddress(GeoPoint point, int selection) async {
    try {
      final address = await ref.read(customerLocationAddressProvider)(point);
      if (!mounted ||
          !widget.enabled ||
          selection != _selection ||
          address == null) {
        return;
      }
      widget.onAddressChanged?.call(address);
    } catch (_) {
      // Keep the selected GPS pin; location search remains available for an address.
    }
  }

  Future<void> _gps({bool initial = false}) async {
    final selection = _selection;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final p = await ref.read(customerDeviceLocationProvider)();
      if (!mounted ||
          !widget.enabled ||
          initial && (widget.point != null || selection != _selection)) {
        return;
      }
      _choose(p);
      _moveCamera(p);
    } catch (e) {
      if (mounted &&
          (!initial || widget.point == null && selection == _selection)) {
        setState(
          () => _error = e is BookingProblem ? e.message : 'Unable to get your location. Tap the map to choose a pin instead.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _moveCamera(GeoPoint point) async {
    try {
      final pins = providerMapPins(
        widget.candidates,
        searchPoint: point,
        radiusKm: widget.radiusKm,
      );
      if (pins.isNotEmpty) {
        final latDelta = widget.radiusKm * 1000 / 111320;
        final lngDelta =
            latDelta /
            math.cos(point.latitude * math.pi / 180).abs().clamp(.01, 1);
        final latitudes = [
          point.latitude - latDelta,
          point.latitude + latDelta,
          ...pins.map((pin) => pin.displayLocation.latitude),
          ...pins.map((pin) => pin.location.latitude),
        ];
        final longitudes = [
          point.longitude - lngDelta,
          point.longitude + lngDelta,
          ...pins.map((pin) => pin.displayLocation.longitude),
          ...pins.map((pin) => pin.location.longitude),
        ];
        await _map?.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                latitudes.reduce(math.min).clamp(-90, 90),
                longitudes.reduce(math.min).clamp(-180, 180),
              ),
              northeast: LatLng(
                latitudes.reduce(math.max).clamp(-90, 90),
                longitudes.reduce(math.max).clamp(-180, 180),
              ),
            ),
            24,
          ),
        );
        return;
      }
      await _map?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(point.latitude, point.longitude),
            zoom: _radiusZoom,
          ),
        ),
      );
    } catch (_) {
      // A platform view can be disposed while a GPS/search result is arriving.
    }
  }

  void _loadMarkerIcons() {
    for (final candidate in widget.candidates) {
      final photo = widget.preferProviderPhotos && candidate.markerIcon == null;
      final url = candidate.markerIcon ?? (photo ? candidate.photo : null);
      final key = photo ? 'photo:$url' : url;
      if (url == null || key == null || !_loadingIcons.add(key)) continue;
      final loader = ref.read(
        photo
            ? customerProviderPhotoMarkerLoaderProvider
            : customerMarkerIconLoaderProvider,
      );
      loader(url).then((icon) {
        if (mounted && icon != null) setState(() => _icons[key] = icon);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;
    final pins = providerMapPins(
      widget.candidates,
      searchPoint: p,
      radiusKm: widget.radiusKm,
    );
    _loadMarkerIcons();
    final camera = CameraPosition(
      target: p == null
          ? const LatLng(7.8731, 80.7718)
          : LatLng(p.latitude, p.longitude),
      zoom: p == null ? 6.5 : _radiusZoom,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.mapOnly)
          Text(
            widget.label,
            style: const TextStyle(
              color: catalogInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (!widget.mapOnly) const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.mapOnly ? 0 : 18),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                ref.watch(customerMapBuilderProvider)(
                  CustomerMapState(
                    camera: camera,
                    onCreated: (controller) {
                      if (!mounted) {
                        controller.dispose();
                        return;
                      }
                      _map = controller;
                      if (widget.point case final point?) _moveCamera(point);
                    },
                    onSelect: widget.enabled
                        ? (value) =>
                              _choose(GeoPoint(value.latitude, value.longitude))
                        : null,

                    circles: {
                      if (p != null)
                        Circle(
                          circleId: const CircleId('search-radius'),
                          center: LatLng(p.latitude, p.longitude),
                          radius: widget.radiusKm * 1000,
                          fillColor: catalogTeal.withValues(alpha: .12),
                          strokeColor: catalogTeal,
                          strokeWidth: 1,
                        ),
                    },
                    polylines: {
                      for (final pin in pins.where((pin) => pin.separated))
                        Polyline(
                          polylineId: PolylineId(
                            'provider-link-${pin.candidate.key}',
                          ),
                          points: [pin.location, pin.displayLocation],
                          color: catalogTeal.withValues(alpha: .55),
                          width: 1,
                        ),
                    },
                    markers: {
                      if (p != null)
                        Marker(
                          markerId: const MarkerId('service-location'),
                          position: LatLng(p.latitude, p.longitude),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueCyan,
                          ),
                          draggable: widget.enabled,
                          onDragEnd: widget.enabled
                              ? (value) => _choose(
                                  GeoPoint(value.latitude, value.longitude),
                                )
                              : null,
                        ),
                      for (final pin in pins)
                        Marker(
                          markerId: MarkerId('provider-${pin.candidate.key}'),
                          position: pin.displayLocation,
                          onTap: widget.onProviderSelected == null
                              ? null
                              : () => widget.onProviderSelected!(pin.candidate),
                          icon:
                              _icons[pin.candidate.markerIcon ??
                                  (widget.preferProviderPhotos
                                      ? 'photo:${pin.candidate.photo}'
                                      : null)] ??
                              BitmapDescriptor.defaultMarker,
                          anchor:
                              pin.candidate.markerIcon == null &&
                                  widget.preferProviderPhotos &&
                                  _icons['photo:${pin.candidate.photo}'] != null
                              ? const Offset(.5, .5)
                              : const Offset(.5, 1),
                          infoWindow: InfoWindow(
                            title: pin.candidate.name,
                            snippet: pin.separated
                                ? 'Shared location · pin separated for visibility'
                                : switch (pin.candidate.data['locationLabel']) {
                                    'APPROXIMATE_SERVICE_AREA' =>
                                      'Approximate service area',
                                    'PUBLIC_SERVICE_LOCATION' =>
                                      'Provider location',
                                    _ => null,
                                  },
                          ),
                        ),
                    },
                  ),
                ),
                if (widget.mapOnly && _error != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 100,
                    left: 16,
                    right: 16,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: catalogInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.enabled || widget.showRecenter)
                  Positioned(
                    top: widget.mapOnly ? null : 8,
                    bottom: widget.mapOnly
                        ? (widget.height < 72 ? 0 : 12)
                        : null,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: widget.enabled
                            ? 'Use current location'
                            : 'Recenter search area',
                        onPressed: _locating
                            ? null
                            : widget.enabled
                            ? _gps
                            : p == null
                            ? null
                            : () => _moveCamera(p),
                        icon: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location, color: catalogTeal),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!widget.mapOnly && p == null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Tap the map to choose a location, or use your current location.',
              style: TextStyle(fontSize: 12, color: catalogMuted),
            ),
          ),
        if (!widget.mapOnly && _error != null)
          Text(_error!, style: const TextStyle(color: CustomerColors.error)),
        if (widget.candidates.isNotEmpty && !widget.mapOnly)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Markers show public provider locations or approximate service areas—not live positions.',
              style: TextStyle(color: catalogMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
