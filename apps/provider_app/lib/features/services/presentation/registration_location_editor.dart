import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/providers/app_providers.dart';
import '../data/registration_geocoder.dart';
import 'registration_widgets.dart';

Future<Map<String, dynamic>?> showRegistrationLocation(
  BuildContext context, {
  Map<String, dynamic>? initial,
  required String mode,
}) => Navigator.of(context).push<Map<String, dynamic>>(
  MaterialPageRoute(
    builder: (_) =>
        RegistrationLocationPicker(initial: initial ?? {}, mode: mode),
  ),
);

double serviceAreaMapZoom(LatLng? point, double? radiusKm) {
  if (point == null) return 2;
  if (radiusKm == null || !radiusKm.isFinite || radiusKm <= 0) return 11;
  final scale = 156543.03392 * math.cos(point.latitude * math.pi / 180).abs();
  return (math.log(scale * 240 / (radiusKm * 2000)) / math.ln2)
      .clamp(2, 18)
      .toDouble();
}

/// Injectable map surface keeps location selection testable without platform views.
final registrationMapBuilderProvider =
    Provider<Widget Function(RegistrationMapState)>(
      (ref) =>
          (state) => GoogleMap(
            initialCameraPosition: CameraPosition(
              target: state.point ?? const LatLng(0, 0),
              zoom: serviceAreaMapZoom(state.point, state.radiusKm),
            ),
            onMapCreated: state.onCreated,
            onTap: state.onSelect,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              if (state.point != null)
                Marker(
                  markerId: const MarkerId('service-location'),
                  position: state.point!,
                  draggable: true,
                  onDragEnd: state.onSelect,
                ),
            },
            circles: {
              if (state.point != null &&
                  state.radiusKm != null &&
                  state.radiusKm! > 0)
                Circle(
                  circleId: const CircleId('service-area'),
                  center: state.point!,
                  radius: state.radiusKm! * 1000,
                  strokeColor: registrationTeal,
                  strokeWidth: 2,
                  fillColor: registrationTeal.withValues(alpha: .13),
                ),
            },
          ),
    );

class RegistrationMapState {
  const RegistrationMapState({
    required this.point,
    required this.radiusKm,
    required this.onSelect,
    required this.onCreated,
  });
  final LatLng? point;
  final double? radiusKm;
  final ValueChanged<LatLng> onSelect;
  final ValueChanged<GoogleMapController> onCreated;
}

class RegistrationLocationPicker extends ConsumerStatefulWidget {
  const RegistrationLocationPicker({
    required this.initial,
    required this.mode,
    super.key,
  });
  final Map<String, dynamic> initial;
  final String mode;
  @override
  ConsumerState<RegistrationLocationPicker> createState() => _LocationState();
}

class _LocationState extends ConsumerState<RegistrationLocationPicker> {
  final form = GlobalKey<FormState>();
  final search = TextEditingController();
  late final TextEditingController name, latitude, longitude, radius;
  late Map<String, dynamic> values;
  LatLng? point;
  GoogleMapController? map;
  String? error;
  bool searching = false, resolving = false;
  int generation = 0;
  List<Map<String, dynamic>> results = [];
  bool get visitsCustomer => widget.mode == 'PROVIDER_TO_CUSTOMER';
  double? get radiusKm {
    final value = visitsCustomer ? double.tryParse(radius.text) : null;
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  @override
  void initState() {
    super.initState();
    values = Map.of(widget.initial);
    name = TextEditingController(text: values['locationName'] as String? ?? '');
    latitude = TextEditingController(
      text: values['latitude']?.toString() ?? '',
    );
    longitude = TextEditingController(
      text: values['longitude']?.toString() ?? '',
    );
    radius = TextEditingController(text: values['radiusKm']?.toString() ?? '');
    point = parsePoint();
  }

  LatLng? parsePoint() {
    final lat = double.tryParse(latitude.text),
        lng = double.tryParse(longitude.text);
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  @override
  void dispose() {
    generation++;
    map?.dispose();
    for (final controller in [search, name, latitude, longitude, radius]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> find() async {
    if (search.text.trim().isEmpty) return;
    final request = ++generation;
    setState(() {
      searching = true;
      resolving = false;
      error = null;
    });
    try {
      final found = await ref
          .read(registrationGeocoderProvider)
          .search(search.text.trim());
      if (!mounted || request != generation) return;
      setState(() {
        results = found;
        if (found.isEmpty) {
          error = 'No locations found. Try a more specific address.';
        }
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error = 'Address search is unavailable. Select a point on the map or retry.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => searching = false);
    }
  }

  Future<void> select(LatLng selected, {String? label}) async {
    final request = ++generation;
    setState(() {
      point = selected;
      results = [];
      searching = false;
      resolving = true;
      error = null;
      latitude.text = '${selected.latitude}';
      longitude.text = '${selected.longitude}';
      name.text = label ?? '';
      for (final key in ['country', 'province', 'district', 'city']) {
        values.remove(key);
      }
    });
    map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        selected,
        serviceAreaMapZoom(selected, radiusKm),
      ),
    );
    try {
      final address = await ref
          .read(registrationGeocoderProvider)
          .reverse(selected.latitude, selected.longitude);
      if (!mounted || request != generation) return;
      setState(() {
        values.addAll(address);
        if (name.text.isEmpty) {
          name.text = address['locationName'] as String? ?? '';
        }
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error = 'The address could not be found. Enter a location name for the selected pin.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => resolving = false);
    }
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final coordinates = parsePoint();
    if (coordinates == null) {
      setState(() => error = 'Select a valid location on the map.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      ...values,
      'locationName': name.text.trim(),
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
      'radiusKm': radiusKm,
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        !kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform);
    final configured =
        ref.watch(appConfigProvider)?.googleMapsApiKey.isNotEmpty == true;
    final canMap = supported && configured;
    return Scaffold(
      appBar: AppBar(title: const Text('Service Location & Area')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                key: const ValueKey('location-search'),
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => find(),
                decoration: InputDecoration(
                  hintText: 'Search for a city or address',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Search locations',
                          onPressed: find,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                ),
              ),
              for (final (index, result) in results.indexed)
                ListTile(
                  key: ValueKey('location-result-$index'),
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text('${result['locationName']}'),
                  subtitle: Text(
                    '${result['latitude']}, ${result['longitude']}',
                  ),
                  onTap: () => select(
                    LatLng(
                      (result['latitude'] as num).toDouble(),
                      (result['longitude'] as num).toDouble(),
                    ),
                    label: result['locationName'] as String?,
                  ),
                ),
              const SizedBox(height: 14),
              if (canMap)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 320,
                    child: ref.watch(registrationMapBuilderProvider)(
                      RegistrationMapState(
                        point: point,
                        radiusKm: radiusKm,
                        onSelect: select,
                        onCreated: (controller) {
                          if (!mounted) {
                            controller.dispose();
                            return;
                          }
                          map = controller;
                        },
                      ),
                    ),
                  ),
                )
              else
                const RegistrationNotice(
                  'The map is unavailable on this build. Enter an address and coordinates below.',
                  warning: true,
                ),
              const SizedBox(height: 8),
              if (canMap)
                registrationText(
                  'Tap the map or drag the pin to select where you provide this service.',
                  12,
                  color: registrationMuted,
                ),
              if (resolving) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('location-name'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Location name'),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Enter a location name.',
              ),
              if (visitsCustomer) ...[
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('location-radius'),
                  controller: radius,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Service radius',
                    suffixText: 'km',
                  ),
                  validator: (_) =>
                      radiusKm != null && radiusKm!.isFinite && radiusKm! > 0
                      ? null
                      : 'Enter a positive service radius.',
                ),
              ],
              ExpansionTile(
                title: const Text('Address details'),
                initiallyExpanded: !canMap,
                children: [
                  for (final entry in [
                    ('country', 'Country'),
                    ('province', 'Province'),
                    ('district', 'District'),
                    ('city', 'City'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextFormField(
                        key: ValueKey('${entry.$1}-$generation'),
                        initialValue: values[entry.$1] as String? ?? '',
                        decoration: InputDecoration(labelText: entry.$2),
                        onChanged: (text) => values[entry.$1] = text.trim(),
                      ),
                    ),
                  Row(
                    children: [
                      for (final entry in [
                        (latitude, 'Latitude'),
                        (longitude, 'Longitude'),
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: TextFormField(
                              controller: entry.$1,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: InputDecoration(labelText: entry.$2),
                              onChanged: (_) {
                                generation++;
                                setState(() {
                                  point = parsePoint();
                                  resolving = false;
                                  searching = false;
                                });
                              },
                              validator: (_) => parsePoint() == null
                                  ? 'Enter valid coordinates.'
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (error != null) RegistrationNotice(error!, warning: true),
              const SizedBox(height: 16),
              RegistrationButton(
                'Save Location',
                onPressed: resolving || searching ? null : save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRegistrationAreas(
  BuildContext context,
  List<Map<String, dynamic>> areas,
  String mode,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _AreaOverview(areas: areas, mode: mode),
  ),
);

class _AreaOverview extends ConsumerWidget {
  const _AreaOverview({required this.areas, required this.mode});
  final List<Map<String, dynamic>> areas;
  final String mode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valid = areas
        .where((area) => area['latitude'] is num && area['longitude'] is num)
        .toList();
    final configured =
        ref.watch(appConfigProvider)?.googleMapsApiKey.isNotEmpty == true;
    final supported =
        !kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform);
    LatLng position(Map area) => LatLng(
      (area['latitude'] as num).toDouble(),
      (area['longitude'] as num).toDouble(),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Service Areas')),
      body: Column(
        children: [
          Expanded(
            child: valid.isEmpty
                ? const Center(
                    child: Text('Add a service location to view its area.'),
                  )
                : !configured || !supported
                ? const Center(
                    child: Text('The map is unavailable on this build.'),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: position(valid.first),
                      zoom: 10,
                    ),
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (controller) {
                      if (valid.length < 2) return;
                      final latitudes =
                          valid
                              .map(
                                (area) => (area['latitude'] as num).toDouble(),
                              )
                              .toList()
                            ..sort();
                      final longitudes =
                          valid
                              .map(
                                (area) => (area['longitude'] as num).toDouble(),
                              )
                              .toList()
                            ..sort();
                      if (latitudes.first == latitudes.last &&
                          longitudes.first == longitudes.last) {
                        return;
                      }
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(
                              latitudes.first,
                              longitudes.first,
                            ),
                            northeast: LatLng(latitudes.last, longitudes.last),
                          ),
                          50,
                        ),
                      );
                    },
                    markers: {
                      for (final (index, area) in valid.indexed)
                        Marker(
                          markerId: MarkerId('area-$index'),
                          position: position(area),
                          infoWindow: InfoWindow(
                            title: area['locationName'] as String?,
                          ),
                        ),
                    },
                    circles: {
                      if (mode == 'PROVIDER_TO_CUSTOMER')
                        for (final (index, area) in valid.indexed)
                          if (area['radiusKm'] is num &&
                              (area['radiusKm'] as num) > 0)
                            Circle(
                              circleId: CircleId('radius-$index'),
                              center: position(area),
                              radius:
                                  (area['radiusKm'] as num).toDouble() * 1000,
                              strokeWidth: 2,
                              strokeColor: registrationTeal,
                              fillColor: registrationTeal.withValues(
                                alpha: .13,
                              ),
                            ),
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                areas
                    .map((area) => area['locationName'])
                    .whereType<String>()
                    .join(' • '),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
