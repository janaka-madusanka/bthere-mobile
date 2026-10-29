import 'dart:async';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider_app/features/services/data/registration_device_location.dart';

class FakeDeviceLocation implements RegistrationDeviceLocation {
  FakeDeviceLocation({this.position = const LatLng(6.9, 79.8), this.issue});
  final LatLng position;
  final DeviceLocationIssue? issue;
  Completer<LatLng>? pending;
  int calls = 0, settings = 0;
  @override
  Future<LatLng> current() async {
    calls++;
    if (pending != null) return pending!.future;
    if (issue != null) throw DeviceLocationException(issue!);
    return position;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}
