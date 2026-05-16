import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'campus_geo_constants.dart';
import 'geo_fence_outcome.dart';

/// Campus geo-fence: OS location services, runtime permission, GPS sample, polygon.
class GeoFenceService {
  GeoFenceService._();
  static final GeoFenceService instance = GeoFenceService._();

  /// Gate card: GPS drift tolerance near polygon edges (meters).
  static const double gateGpsBufferMeters = 120;

  Future<bool> isInsideCampus() async =>
      (await evaluateCampusBoundary()) == GeoFenceOutcome.inside;

  Future<GeoFenceOutcome> evaluateCampusBoundary({
    List<CampusLatLng> polygon = campusPolygon,
  }) =>
      evaluateCampusBoundaries(polygons: <List<CampusLatLng>>[polygon]);

  /// Inside if the device is within **any** polygon (optional [bufferMeters] for gate).
  Future<GeoFenceOutcome> evaluateCampusBoundaries({
    required List<List<CampusLatLng>> polygons,
    double bufferMeters = 0,
    bool preferGateAccuracy = false,
  }) async {
    if (kIsWeb) {
      return GeoFenceOutcome.locationUnavailable;
    }

    final valid = polygons.where((p) => p.length >= 3).toList();
    if (valid.isEmpty) {
      return GeoFenceOutcome.locationUnavailable;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return GeoFenceOutcome.locationServiceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return GeoFenceOutcome.permissionDenied;
    }
    if (permission == LocationPermission.unableToDetermine) {
      return GeoFenceOutcome.locationUnavailable;
    }

    try {
      Position? position;

      if (preferGateAccuracy) {
        position = await _resolveGatePosition(
          polygons: valid,
          bufferMeters: bufferMeters,
        );
      } else {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 25),
          ),
        );
      }

      if (position == null) {
        return GeoFenceOutcome.locationUnavailable;
      }

      final inside = _isInsideAnyPolygon(
        latitude: position.latitude,
        longitude: position.longitude,
        polygons: valid,
        bufferMeters: bufferMeters,
        useCentroidBuffer: !preferGateAccuracy,
      );

      if (kDebugMode) {
        debugPrint(
          '[GeoFence] lat=${position.latitude} lon=${position.longitude} '
          'buffer=${bufferMeters}m inside=$inside',
        );
      }

      return inside ? GeoFenceOutcome.inside : GeoFenceOutcome.outsideCampus;
    } on TimeoutException {
      return GeoFenceOutcome.locationUnavailable;
    } catch (e, st) {
      debugPrint('[GeoFenceService] evaluateCampusBoundaries failed: $e');
      debugPrintStack(label: '[GeoFenceService] stack', stackTrace: st);
      return GeoFenceOutcome.locationUnavailable;
    }
  }

  /// Fresh fix for gate; reuses last-known only when already inside a campus envelope.
  static Future<Position?> _resolveGatePosition({
    required List<List<CampusLatLng>> polygons,
    required double bufferMeters,
  }) async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null &&
        _isRecentPosition(last) &&
        _isInsideAnyPolygon(
          latitude: last.latitude,
          longitude: last.longitude,
          polygons: polygons,
          bufferMeters: bufferMeters,
          useCentroidBuffer: false,
        )) {
      return last;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  static bool _isRecentPosition(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= const Duration(minutes: 3);
  }

  static bool _isInsideAnyPolygon({
    required double latitude,
    required double longitude,
    required List<List<CampusLatLng>> polygons,
    required double bufferMeters,
    bool useCentroidBuffer = true,
  }) {
    for (final polygon in polygons) {
      if (_isInsidePolygonWithBuffer(
        latitude: latitude,
        longitude: longitude,
        polygon: polygon,
        bufferMeters: bufferMeters,
        useCentroidBuffer: useCentroidBuffer,
      )) {
        return true;
      }
    }
    return false;
  }

  static bool _isInsidePolygonWithBuffer({
    required double latitude,
    required double longitude,
    required List<CampusLatLng> polygon,
    required double bufferMeters,
    bool useCentroidBuffer = true,
  }) {
    if (pointInCampusPolygon(
      latitude: latitude,
      longitude: longitude,
      polygon: polygon,
    )) {
      return true;
    }
    if (bufferMeters <= 0) return false;

    for (final p in polygon) {
      final d = Geolocator.distanceBetween(
        latitude,
        longitude,
        p.latitude,
        p.longitude,
      );
      if (d <= bufferMeters) return true;
    }

    if (!useCentroidBuffer) return false;

    final c = _polygonCentroid(polygon);
    final maxR = _maxVertexDistanceMeters(c, polygon) + bufferMeters;
    final toCenter = Geolocator.distanceBetween(
      latitude,
      longitude,
      c.latitude,
      c.longitude,
    );
    return toCenter <= maxR;
  }

  static CampusLatLng _polygonCentroid(List<CampusLatLng> polygon) {
    var lat = 0.0;
    var lon = 0.0;
    for (final p in polygon) {
      lat += p.latitude;
      lon += p.longitude;
    }
    final n = polygon.length;
    return CampusLatLng(lat / n, lon / n);
  }

  static double _maxVertexDistanceMeters(
    CampusLatLng center,
    List<CampusLatLng> polygon,
  ) {
    var max = 0.0;
    for (final p in polygon) {
      final d = Geolocator.distanceBetween(
        center.latitude,
        center.longitude,
        p.latitude,
        p.longitude,
      );
      max = math.max(max, d);
    }
    return max;
  }

  static bool pointInCampusPolygon({
    required double latitude,
    required double longitude,
    List<CampusLatLng> polygon = campusPolygon,
  }) {
    return _pointInPolygonRayCast(
      pointLat: latitude,
      pointLon: longitude,
      polygon: polygon,
    );
  }
}

bool _pointInPolygonRayCast({
  required double pointLat,
  required double pointLon,
  required List<CampusLatLng> polygon,
}) {
  if (polygon.length < 3) return false;

  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final yi = polygon[i].latitude;
    final xi = polygon[i].longitude;
    final yj = polygon[j].latitude;
    final xj = polygon[j].longitude;

    final dy = yj - yi;
    if (dy.abs() < 1e-12) {
      continue;
    }

    final crossesMeridian = (yi > pointLat) != (yj > pointLat);
    if (!crossesMeridian) continue;

    final xIntersect = xi + (xj - xi) * (pointLat - yi) / dy;
    if (pointLon < xIntersect) {
      inside = !inside;
    }
  }
  return inside;
}
