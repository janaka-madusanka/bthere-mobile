import '../../../app/customer_theme.dart';

import 'dart:async';

import 'package:bthere_design_system/bthere_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/customer_place_search.dart';
import '../domain/booking_models.dart';
import 'booking_location_picker.dart';
import '../../discovery/presentation/customer_discovery_style.dart';

class BookingLocationDialog extends ConsumerStatefulWidget {
  const BookingLocationDialog({
    super.key,
    required this.point,
    required this.address,
    required this.radius,
    required this.title,
    this.countryCode,
  });
  final GeoPoint? point;
  final String address, title;
  final double radius;
  final String? countryCode;
  @override
  ConsumerState<BookingLocationDialog> createState() =>
      _BookingLocationDialogState();
}

class _BookingLocationDialogState extends ConsumerState<BookingLocationDialog> {
  late GeoPoint? _point = widget.point;
  final _query = TextEditingController();
  late String _address = widget.address;
  List<PlaceResult> _results = [];
  bool _loading = false, _searched = false, _fromSearch = false;
  String? _error;
  int _request = 0;
  Timer? _searchTimer;
  bool _wasComposing = false;
  List<String> _attributions = [];
  @override
  void initState() {
    super.initState();
    _query.addListener(_compositionChanged);
  }

  void _compositionChanged() {
    final composing = _query.value.composing;
    final active = composing.isValid && !composing.isCollapsed;
    final committed = _wasComposing && !active;
    _wasComposing = active;
    if (committed) _queryChanged(_query.text);
  }

  @override
  void dispose() {
    _request++;
    _searchTimer?.cancel();
    _query.removeListener(_compositionChanged);
    _query.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    _searchTimer?.cancel();
    final request = ++_request;
    setState(() {
      _loading = false;
      _results = [];
      _searched = false;
      _error = null;
    });
    final query = value.trim();
    if (query.length < 2 || query.length > 200) return;
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || request != _request) return;
      final composing = _query.value.composing;
      if (composing.isValid && !composing.isCollapsed) return;
      _search(manual: false);
    });
  }

  Future<void> _search({bool manual = true}) async {
    _searchTimer?.cancel();
    if (_loading) return;
    final query = _query.text.trim();
    if (query.length < 2 || query.length > 200) {
      setState(
        () => _error = 'Enter a city, area or place name (2-200 characters).',
      );
      return;
    }
    final request = ++_request;
    if (manual) FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = false;
      _results = [];
    });
    try {
      final results = await ref
          .read(customerPlaceSearchProvider)
          .search(query, countryCode: widget.countryCode);
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is BookingProblem ? error.message : 'Unable to search locations. Try again or choose a pin on the map.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _select(PlaceResult result) async {
    if (_loading) return;
    _searchTimer?.cancel();
    final request = ++_request;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolved = await ref
          .read(customerPlaceSearchProvider)
          .resolve(result);
      if (!mounted || request != _request) return;
      final point = resolved.point;
      if (point == null || !point.valid) {
        throw const BookingProblem(
          'That location could not be selected. Try another result.',
        );
      }
      setState(() {
        _point = point;
        _address = resolved.address;
        _attributions = resolved.attributions;
        _results = [];
        _searched = false;
        _fromSearch = true;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is BookingProblem
              ? error.message
              : 'Unable to select that location. Try again or choose a pin.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Widget _attribution(String html) {
    final link = RegExp('href=["\']([^"\']+)["\']').firstMatch(html)?.group(1);
    final uri = link == null ? null : Uri.tryParse(link);
    final label = html
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll('&amp;', '&');
    return TextButton(
      onPressed: uri != null && {'https', 'http'}.contains(uri.scheme)
          ? () => launchUrl(uri, mode: LaunchMode.externalApplication)
          : null,
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _point == null || _loading
                  ? null
                  : () => Navigator.pop(context, (_point!, _address.trim())),
              style: FilledButton.styleFrom(
                backgroundColor: catalogTeal,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Use this location'),
            ),
            const SizedBox(height: 6),
            const Image(
              image:
                  FlutterGooglePlacesSdk.ASSET_POWERED_BY_GOOGLE_ON_NON_WHITE,
              height: 16,
              fit: BoxFit.contain,
              semanticLabel: 'Powered by Google',
            ),
            if (_attributions.isNotEmpty)
              Wrap(
                children: [
                  for (final credit in _attributions) _attribution(credit),
                ],
              ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('booking-place-query'),
                        controller: _query,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'Search service location',
                          hintText: 'City, area or place name',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: _queryChanged,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const ValueKey('booking-place-search'),
                      tooltip: 'Search locations',
                      onPressed: _loading ? null : _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: BThereLoadingState(
                    label: 'Searching locations',
                    compact: true,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: CustomerColors.error),
                  ),
                ),
              if (_searched && _results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No locations found. Try a nearby city, area or landmark.',
                  ),
                ),
              for (final result in _results)
                Material(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: catalogTeal,
                    ),
                    title: Text(result.title),
                    subtitle: Text(result.address),
                    onTap: _loading ? null : () => _select(result),
                  ),
                ),
              BookingLocationPicker(
                point: _point,
                radiusKm: widget.radius,
                mapOnly: true,
                autoLocate: true,
                onAddressChanged: (address) =>
                    setState(() => _address = address),
                height: (bounds.maxHeight - 86).clamp(180, 900),
                onChanged: (value) => setState(() {
                  _searchTimer?.cancel();
                  _request++;
                  _loading = false;
                  _results = [];
                  _searched = false;
                  _attributions = [];
                  _point = value;
                  _address = '';
                  if (_fromSearch) {
                    _address = '';
                    _fromSearch = false;
                  }
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
