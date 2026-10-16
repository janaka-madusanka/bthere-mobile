import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DeviceLocationIssue { denied, deniedForever, disabled, unavailable }

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.issue);
  final DeviceLocationIssue issue;
}

abstract interface class RegistrationDeviceLocation {
  Future<LatLng> current();
  Future<bool> openSettings();
}

final registrationDeviceLocationProvider = Provider<RegistrationDeviceLocation>(
  (ref) => NativeRegistrationDeviceLocation(),
);

class NativeRegistrationDeviceLocation implements RegistrationDeviceLocation {
  @override
  Future<LatLng> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(DeviceLocationIssue.disabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(DeviceLocationIssue.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const DeviceLocationException(DeviceLocationIssue.denied);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
