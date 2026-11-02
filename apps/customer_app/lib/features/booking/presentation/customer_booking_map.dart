import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Allows journey tests to exercise maps without a native platform view.
final customerMapBuilderProvider = Provider<Widget Function(CustomerMapState)>(
  (ref) => (state) {
    const key = String.fromEnvironment('BTHERE_GOOGLE_MAPS_API_KEY');
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported || key.trim().isEmpty) {
      return ColoredBox(
        color: const Color(0xFFE9F6F4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              !supported
                  ? 'Google Maps is available in the Android and iOS apps.'
                  : 'Map unavailable. Configure Google Maps and restart the app. You can still use location search or your current location.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return GoogleMap(
      initialCameraPosition: state.camera,
      onMapCreated: state.onCreated,
      onTap: state.onSelect,
      markers: state.markers,
      circles: state.circles,
      polylines: state.polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      // Keep Google attribution above the draggable booking panel.
      padding: EdgeInsets.only(bottom: state.bottomPadding),
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  },
);

class CustomerMapState {
  const CustomerMapState({
    required this.camera,
    required this.onCreated,
    required this.onSelect,
    required this.markers,
    required this.circles,
    this.polylines = const {},
    this.bottomPadding = 0,
  });
  final CameraPosition camera;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<LatLng>? onSelect;
  final Set<Marker> markers;
  final Set<Circle> circles;
  final Set<Polyline> polylines;
  final double bottomPadding;
}
