import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/providers/app_providers.dart';
import '../data/registration_device_location.dart';
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

double serviceAreaMapZoom(
  LatLng? point,
  double? radiusKm, {
  double viewportExtent = 180,
}) {
  if (point == null) return 2;
  if (radiusKm == null || !radiusKm.isFinite || radiusKm <= 0) return 14;
  final scale = 156543.03392 * math.cos(point.latitude * math.pi / 180).abs();
  return (math.log(scale * viewportExtent / (radiusKm * 2000)) / math.ln2)
      .clamp(2, 18)
      .toDouble();
}

LatLng? _areaPoint(Map area) {
  final lat = area['latitude'], lng = area['longitude'];
  if (lat is! num ||
      lng is! num ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return LatLng(lat.toDouble(), lng.toDouble());
}

bool get _nativeMaps =>
    !kIsWeb &&
    [
      TargetPlatform.android,
      TargetPlatform.iOS,
    ].contains(defaultTargetPlatform);
Circle _coverage(String id, LatLng point, double radius) => Circle(
  circleId: CircleId(id),
  center: point,
  radius: radius * 1000,
  strokeColor: registrationTeal,
  strokeWidth: 2,
  fillColor: registrationTeal.withValues(alpha: .13),
);

final registrationMapBuilderProvider =
    Provider<Widget Function(RegistrationMapState)>(
      (ref) =>
          (state) => GoogleMap(
            initialCameraPosition: CameraPosition(
              target: state.point ?? const LatLng(0, 0),
              zoom: serviceAreaMapZoom(
                state.point,
                state.radiusKm,
                viewportExtent: state.viewportExtent,
              ),
            ),
            onMapCreated: state.onCreated,
            onTap: state.readOnly ? null : state.onSelect,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            markers:
                state.markers ??
                {
                  if (state.point != null)
                    Marker(
                      markerId: const MarkerId('service-location'),
                      position: state.point!,
                      draggable: !state.readOnly,
                      onDragEnd: state.onSelect,
                    ),
                },
            circles:
                state.circles ??
                {
                  if (state.point != null &&
                      state.radiusKm != null &&
                      state.radiusKm! > 0)
                    _coverage('service-area', state.point!, state.radiusKm!),
                },
          ),
    );

class RegistrationMapState {
  const RegistrationMapState({
    required this.point,
    required this.radiusKm,
    required this.onSelect,
    required this.onCreated,
    this.readOnly = false,
    this.viewportExtent = 180,
    this.markers,
    this.circles,
  });
  final LatLng? point;
  final double? radiusKm;
  final double viewportExtent;
  final ValueChanged<LatLng> onSelect;
  final ValueChanged<GoogleMapController> onCreated;
  final bool readOnly;
  final Set<Marker>? markers;
  final Set<Circle>? circles;
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
  late final TextEditingController name, radius;
  late Map<String, dynamic> values;
  LatLng? point;
  GoogleMapController? map;
  double mapViewportExtent = 180;
  String? error;
  DeviceLocationIssue? locationIssue;
  bool searching = false, resolving = false, locating = false;
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
    radius = TextEditingController(
      text: values['radiusKm']?.toString() ?? (visitsCustomer ? '5' : ''),
    );
    point = _areaPoint(values);
    if (point == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(useCurrentLocation());
      });
    }
  }

  @override
  void dispose() {
    generation++;
    map?.dispose();
    for (final controller in [search, name, radius]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    if (locating) return;
    final request = ++generation;
    setState(() {
      locating = true;
      searching = false;
      resolving = false;
      error = null;
      locationIssue = null;
      results = [];
    });
    try {
      final current = await ref
          .read(registrationDeviceLocationProvider)
          .current()
          .timeout(const Duration(seconds: 20));
      if (!mounted || request != generation) return;
      setState(() => locating = false);
      await select(current, label: 'Current location');
    } catch (failure) {
      if (!mounted || request != generation) return;
      setState(() {
        locationIssue = failure is DeviceLocationException
            ? failure.issue
            : DeviceLocationIssue.unavailable;
        error = switch (locationIssue) {
          DeviceLocationIssue.disabled =>
            'Turn on your device location, or search for an address.',
          DeviceLocationIssue.deniedForever => 'Location access is off. Enable it in Settings, or search for an address.',
          DeviceLocationIssue.denied =>
            'You can search for an address or choose a place on the map.',
          _ => 'We couldn’t find your location. Try again or search for an address.',
        };
      });
    } finally {
      if (mounted && request == generation) setState(() => locating = false);
    }
  }

  Future<void> find() async {
    if (search.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final request = ++generation;
    setState(() {
      searching = true;
      resolving = false;
      locating = false;
      error = null;
      locationIssue = null;
    });
    try {
      final found = await ref
          .read(registrationGeocoderProvider)
          .search(search.text.trim());
      if (!mounted || request != generation) return;
      setState(() {
        results = found.where((result) => _areaPoint(result) != null).toList();
        if (results.isEmpty) {
          error = 'No places found. Try a nearby city or a fuller address.';
        }
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error =
              'Search is unavailable. Try again or choose a place on the map.',
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
      locating = false;
      resolving = true;
      error = null;
      locationIssue = null;
      name.text = label ?? '';
      for (final key in ['country', 'province', 'district', 'city']) {
        values.remove(key);
      }
    });
    focus();
    try {
      final address = await ref
          .read(registrationGeocoderProvider)
          .reverse(selected.latitude, selected.longitude);
      if (!mounted || request != generation) return;
      setState(() {
        values.addAll(address);
        if (name.text.isEmpty ||
            (label == 'Current location' && name.text == 'Current location')) {
          name.text = address['locationName'] as String? ?? label ?? '';
        }
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error =
              'The pin is selected. You can give this place a name below.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => resolving = false);
    }
  }

  void focus() {
    if (point != null) {
      map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          point!,
          serviceAreaMapZoom(
            point,
            radiusKm,
            viewportExtent: mapViewportExtent,
          ),
        ),
      );
    }
  }

  void save() {
    if (!form.currentState!.validate() || point == null) return;
    Navigator.pop(context, <String, dynamic>{
      ...values,
      'locationName': name.text.trim().isEmpty
          ? 'Selected location'
          : name.text.trim(),
      'latitude': point!.latitude,
      'longitude': point!.longitude,
      'radiusKm': radiusKm,
    });
  }

  @override
  Widget build(BuildContext context) {
    final canMap =
        _nativeMaps && ref.watch(appConfigProvider)?.hasGoogleMapsKey == true;
    return RegistrationPage(
      step: 2,
      title: 'Service Location & Area',
      showProgress: false,
      onBack: () => Navigator.pop(context),
      footer: RegistrationButton(
        'Save Location',
        onPressed: point == null || locating || resolving || searching
            ? null
            : save,
      ),
      child: const SizedBox.shrink(),
      bodyBuilder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        final mapHeight = math.max(
          130.0,
          bounds.maxHeight - (visitsCustomer ? 336 : 205),
        );
        mapViewportExtent = math.min(180, mapHeight - 36);
        return SingleChildScrollView(
          key: const ValueKey('location-picker-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                registrationText('Set your service area', 19, bold: true),
                const SizedBox(height: 2),
                registrationText(
                  visitsCustomer
                      ? 'Choose your location and travel radius.'
                      : 'Choose where customers will visit you.',
                  11,
                  color: registrationMuted,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('location-search'),
                        controller: search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => find(),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search city or address',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: registrationTeal,
                            size: 20,
                          ),
                          suffixIcon: searching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Search locations',
                                  onPressed: find,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    color: registrationTeal,
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton.filledTonal(
                        key: const ValueKey('use-current-location'),
                        tooltip: 'Use my current location',
                        onPressed: locating ? null : useCurrentLocation,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE5F6F3),
                          foregroundColor: registrationTeal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 21),
                      ),
                    ),
                  ],
                ),
                if (results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 132),
                    child: ListView(
                      shrinkWrap: true,
                      primary: false,
                      children: [
                        for (final (index, result) in results.indexed)
                          ListTile(
                            key: ValueKey('location-result-$index'),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            leading: const Icon(
                              Icons.place_outlined,
                              color: registrationTeal,
                              size: 20,
                            ),
                            title: Text(
                              '${result['locationName']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.north_west, size: 17),
                            onTap: () => select(
                              _areaPoint(result)!,
                              label: result['locationName'] as String?,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _MapCard(
                  available: canMap,
                  height: mapHeight,
                  child: ref.watch(registrationMapBuilderProvider)(
                    RegistrationMapState(
                      point: point,
                      radiusKm: radiusKm,
                      viewportExtent: mapViewportExtent,
                      onSelect: select,
                      onCreated: (controller) {
                        if (!mounted) {
                          controller.dispose();
                          return;
                        }
                        map = controller;
                        focus();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                registrationText(
                  'Tap the map or drag the pin to adjust.',
                  10,
                  color: registrationMuted,
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  RegistrationNotice(error!, warning: true),
                  if (locationIssue == DeviceLocationIssue.deniedForever)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => ref
                            .read(registrationDeviceLocationProvider)
                            .openSettings(),
                        child: const Text('Open Settings'),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFFBFA),
                    border: Border.all(color: const Color(0xFFDDEFEA)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: registrationTeal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: point == null
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: registrationText(
                                  'Select an address or tap the map.',
                                  11,
                                  color: registrationMuted,
                                ),
                              )
                            : TextFormField(
                                key: const ValueKey('location-name'),
                                controller: name,
                                maxLines: 2,
                                minLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Name this location (optional)',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                ),
                              ),
                      ),
                      if (resolving)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                if (visitsCustomer) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: registrationText(
                          'How far can you travel?',
                          13,
                          bold: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: largeText ? 125 : 100,
                        child: TextFormField(
                          key: const ValueKey('location-radius'),
                          controller: radius,
                          onChanged: (_) {
                            setState(() {});
                            focus();
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Radius',
                            suffixText: 'km',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                          ),
                          validator: (_) =>
                              radiusKm == null ? 'Enter a radius > 0' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (largeText)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final km in [5, 10, 15, 25, 50]) _radiusChoice(km),
                      ],
                    )
                  else
                    Row(
                      children: [
                        for (final km in [5, 10, 15, 25, 50]) ...[
                          if (km != 5) const SizedBox(width: 5),
                          Expanded(child: _radiusChoice(km)),
                        ],
                      ],
                    ),
                  SizedBox(
                    height: 30,
                    child: Slider(
                      key: const ValueKey('location-radius-slider'),
                      min: .5,
                      max: math.max(50, radiusKm ?? 5),
                      value: (radiusKm ?? 5).clamp(
                        .5,
                        math.max(50, radiusKm ?? 5),
                      ),
                      label: '${radiusKm ?? 5} km',
                      semanticFormatterCallback: (value) =>
                          '${value.toStringAsFixed(1)} kilometres',
                      onChanged: (value) {
                        final km = (value * 2).round() / 2;
                        setState(
                          () => radius.text = km.toString().replaceFirst(
                            RegExp(r'\.0$'),
                            '',
                          ),
                        );
                        focus();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _radiusChoice(int km) => ChoiceChip(
    label: Text('$km km', style: const TextStyle(fontSize: 11)),
    selected: radiusKm == km,
    showCheckmark: false,
    padding: const EdgeInsets.symmetric(horizontal: 2),
    labelPadding: const EdgeInsets.symmetric(horizontal: 3),
    visualDensity: VisualDensity.compact,
    onSelected: (_) {
      setState(() => radius.text = '$km');
      focus();
    },
  );
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.available,
    required this.child,
    this.height = 300,
    this.overview = false,
  });
  final bool available, overview;
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: height,
      child: available
          ? child
          : ColoredBox(
              color: const Color(0xFFF0F7F7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        size: 38,
                        color: registrationTeal,
                      ),
                      const SizedBox(height: 10),
                      registrationText(
                        'Map preview is unavailable',
                        14,
                        bold: true,
                      ),
                      const SizedBox(height: 6),
                      registrationText(
                        overview ? 'Your saved locations are listed below.' : 'Search for an address above to choose your location.',
                        12,
                        color: registrationMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
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

class _AreaOverview extends ConsumerStatefulWidget {
  const _AreaOverview({required this.areas, required this.mode});
  final List<Map<String, dynamic>> areas;
  final String mode;
  @override
  ConsumerState<_AreaOverview> createState() => _AreaOverviewState();
}

class _AreaOverviewState extends ConsumerState<_AreaOverview> {
  GoogleMapController? map;
  int selected = 0;
  List<Map<String, dynamic>> get areas =>
      widget.areas.where((area) => _areaPoint(area) != null).toList();
  double? radius(Map area) =>
      widget.mode == 'PROVIDER_TO_CUSTOMER' &&
          area['radiusKm'] is num &&
          (area['radiusKm'] as num).isFinite &&
          (area['radiusKm'] as num) > 0
      ? (area['radiusKm'] as num).toDouble()
      : null;
  void focusArea(int index) {
    setState(() => selected = index);
    final area = areas[index];
    map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        _areaPoint(area)!,
        serviceAreaMapZoom(_areaPoint(area), radius(area)),
      ),
    );
  }

  void fitAll() {
    final points = areas.expand((area) {
      final point = _areaPoint(area)!;
      final km = radius(area);
      if (km == null) return [point];
      final latitudeOffset = km / 111.32;
      final longitudeOffset =
          latitudeOffset /
          math.max(.01, math.cos(point.latitude * math.pi / 180).abs());
      return [
        LatLng(
          (point.latitude - latitudeOffset).clamp(-90, 90),
          (point.longitude - longitudeOffset).clamp(-180, 180),
        ),
        LatLng(
          (point.latitude + latitudeOffset).clamp(-90, 90),
          (point.longitude + longitudeOffset).clamp(-180, 180),
        ),
      ];
    }).toList();
    if (points.isEmpty || map == null) return;
    if (points.length == 1 || points.every((point) => point == points.first)) {
      focusArea(0);
      return;
    }
    final south = points.map((point) => point.latitude).reduce(math.min),
        north = points.map((point) => point.latitude).reduce(math.max);
    final west = points.map((point) => point.longitude).reduce(math.min),
        east = points.map((point) => point.longitude).reduce(math.max);
    map!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        55,
      ),
    );
  }

  @override
  void dispose() {
    map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = areas;
    final available =
        _nativeMaps && ref.watch(appConfigProvider)?.hasGoogleMapsKey == true;
    return RegistrationPage(
      step: 2,
      title: 'Your Service Areas',
      showProgress: false,
      footer: RegistrationButton(
        'Done',
        onPressed: () => Navigator.pop(context),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      onBack: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          registrationText('Your service coverage', 22, bold: true),
          const SizedBox(height: 6),
          registrationText(
            widget.mode == 'PROVIDER_TO_CUSTOMER'
                ? 'See the places you serve and how far you travel.'
                : 'See the places where customers can visit you.',
            12,
            color: registrationMuted,
          ),
          const SizedBox(height: 18),
          if (valid.isEmpty)
            RegistrationPanel(
              color: const Color(0xFFEFFBFA),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_location_alt_outlined,
                    size: 40,
                    color: registrationTeal,
                  ),
                  const SizedBox(height: 12),
                  registrationText('No service locations yet', 16, bold: true),
                  const SizedBox(height: 8),
                  registrationText(
                    'Go back and choose a service location to see your coverage here.',
                    12,
                    color: registrationMuted,
                  ),
                ],
              ),
            )
          else ...[
            _MapCard(
              available: available,
              height: 340,
              overview: true,
              child: ref.watch(registrationMapBuilderProvider)(
                RegistrationMapState(
                  point: _areaPoint(valid[selected]),
                  radiusKm: radius(valid[selected]),
                  readOnly: true,
                  onSelect: (_) {},
                  onCreated: (controller) {
                    if (!mounted) {
                      controller.dispose();
                      return;
                    }
                    map = controller;
                    fitAll();
                  },
                  markers: {
                    for (final (index, area) in valid.indexed)
                      Marker(
                        markerId: MarkerId('area-$index'),
                        position: _areaPoint(area)!,
                        infoWindow: InfoWindow(
                          title: area['locationName'] as String?,
                        ),
                        onTap: () => focusArea(index),
                      ),
                  },
                  circles: {
                    for (final (index, area) in valid.indexed)
                      if (radius(area) != null)
                        _coverage(
                          'area-$index',
                          _areaPoint(area)!,
                          radius(area)!,
                        ),
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: fitAll,
                icon: const Icon(Icons.fit_screen, size: 18),
                label: const Text('Show all locations'),
              ),
            ),
            const SizedBox(height: 8),
            registrationText(
              '${valid.length} saved ${valid.length == 1 ? 'location' : 'locations'}',
              15,
              bold: true,
            ),
            const SizedBox(height: 12),
            for (final (index, area) in valid.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RegistrationPanel(
                  color: index == selected
                      ? const Color(0xFFEFFBFA)
                      : Colors.white,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: ValueKey('saved-area-$index'),
                    leading: const Icon(
                      Icons.place_outlined,
                      color: registrationTeal,
                    ),
                    title: registrationText(
                      area['locationName'] as String? ?? 'Service location',
                      13,
                      bold: true,
                    ),
                    subtitle: registrationText(
                      radius(area) == null
                          ? 'Customer visit location'
                          : 'Within ${radius(area)} km',
                      11,
                      color: registrationMuted,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: registrationTeal,
                    ),
                    onTap: () => focusArea(index),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
