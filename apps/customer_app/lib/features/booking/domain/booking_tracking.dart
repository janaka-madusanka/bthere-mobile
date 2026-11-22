import 'dart:convert';

import '../../discovery/domain/customer_discovery.dart';
import 'booking_models.dart';

class BookingTrackingStatus {
  BookingTrackingStatus(
    this.jobId,
    this.status,
    this.mode,
    this.pollSeconds,
    this.payload,
    this.providers,
    this.target,
  );
  final int jobId, pollSeconds;
  final String status, mode;
  final Map<String, dynamic> payload;
  final List<TrackingProvider> providers;
  final GeoPoint? target;
  Uri? get navigation {
    final raw = payload['target'];
    if (raw is! Map || raw['navigationUrl'] is! String || target == null) {
      return null;
    }
    final uri = Uri.tryParse(raw['navigationUrl'] as String);
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'www.google.com', 'maps.google.com'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort && uri.port != 443 ||
        !{'/maps/dir', '/maps/dir/', '/dir', '/dir/'}.contains(uri.path) ||
        uri.queryParameters['api'] != '1') {
      return null;
    }
    final parts = uri.queryParameters['destination']?.split(',');
    if (parts == null || parts.length != 2) return null;
    final lat = double.tryParse(parts[0]), lon = double.tryParse(parts[1]);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        (lat - target!.latitude).abs() > .000001 ||
        (lon - target!.longitude).abs() > .000001) {
      return null;
    }
    return uri;
  }

  String get signature => jsonEncode(payload);
  int get staleSeconds => payload['staleAfterSeconds'] as int? ?? 30;
  bool get showsMap =>
      {'EN_ROUTE', 'IN_TRIP'}.contains(status) ||
      status == 'ARRIVED' && mode == 'FULL_TRIP';
  bool get polls =>
      !{'NOT_SUPPORTED', 'ENDED'}.contains(status) &&
      !(status == 'ARRIVED' && mode != 'FULL_TRIP');
  factory BookingTrackingStatus.parse(Object? raw, int jobId) {
    final value = object(raw);
    final interval = value['pollIntervalSeconds'];
    if (value['jobId'] != jobId ||
        !{
          'NOT_SUPPORTED',
          'WAITING_FOR_CONFIRMATION',
          'NOT_STARTED',
          'EN_ROUTE',
          'ARRIVED',
          'IN_TRIP',
          'ENDED',
        }.contains(value['status']) ||
        value['mode'] is! String ||
        interval is! int ||
        interval <= 0) {
      throw const FormatException('Invalid booking tracking status');
    }
    if (value['status'] == 'IN_TRIP' && value['mode'] != 'FULL_TRIP') {
      throw const FormatException('Invalid tracking mode');
    }
    if (value['staleAfterSeconds'] != null &&
        (value['staleAfterSeconds'] is! int ||
            (value['staleAfterSeconds'] as int) <= 0)) {
      throw const FormatException('Invalid stale interval');
    }
    final providers = <TrackingProvider>[];
    for (final raw in value['providerDisplayFields'] as List? ?? []) {
      if (raw is! Map ||
          raw['fieldId'] is! int ||
          raw['label'] is! String ||
          raw['options'] != null && raw['options'] is! List) {
        throw const FormatException('Invalid public tracking fields');
      }
    }
    final ids = <int>{};
    for (final raw in value['providers'] as List? ?? []) {
      final provider = TrackingProvider.parse(raw);
      if (!ids.add(provider.id)) {
        throw const FormatException('Duplicate tracking provider');
      }
      providers.add(provider);
    }
    final target = value['target'] == null
        ? null
        : GeoPoint.parse(object(value['target']));
    return BookingTrackingStatus(
      jobId,
      value['status'] as String,
      value['mode'] as String,
      interval,
      value,
      providers,
      target,
    );
  }
}

class TrackingProvider {
  TrackingProvider(this.data, this.id, this.name, this.point, this.recordedAt);
  final Map<String, dynamic> data;
  final int id;
  final String name;
  final GeoPoint? point;
  final DateTime? recordedAt;
  String? get photo => safeImageUrl(data['profilePhoto']);
  String? get marker {
    final marker = data['mapMarker'];
    final icon = marker is Map ? marker['icon'] : null;
    return icon is Map ? safeImageUrl(icon['url']) : null;
  }

  double get heading =>
      ((data['location'] as Map?)?['headingDegrees'] as num?)?.toDouble() ?? 0;
  bool stale(DateTime now, int seconds) =>
      data['stale'] == true ||
      recordedAt == null ||
      !now.toUtc().isBefore(recordedAt!.add(Duration(seconds: seconds)));
  factory TrackingProvider.parse(Object? raw) {
    final value = object(raw);
    final location = value['location'] == null
        ? null
        : object(value['location']);
    if (value['providerAttributes'] != null &&
        value['providerAttributes'] is! Map) {
      throw const FormatException('Invalid public provider attributes');
    }
    final point = location == null ? null : GeoPoint.parse(location);
    final recorded = location == null
        ? null
        : DateTime.tryParse('${location['recordedAt']}');
    if (location != null && (recorded == null || !recorded.isUtc) ||
        value['stale'] is! bool) {
      throw const FormatException('Invalid tracking location');
    }
    for (final entry in [
      value['distanceKm'],
      value['etaMinutes'],
      location?['headingDegrees'],
    ]) {
      if (entry != null && (entry is! num || !entry.isFinite || entry < 0)) {
        throw const FormatException('Invalid tracking estimate');
      }
    }
    return TrackingProvider(
      value,
      positiveId(value['providerId']),
      text(value['displayName']),
      point,
      recorded,
    );
  }
}
