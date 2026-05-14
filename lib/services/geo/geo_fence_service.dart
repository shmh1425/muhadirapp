import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'campus_geo_constants.dart';
import 'geo_fence_outcome.dart';

/// Campus geo-fence: OS location services, runtime permission, GPS sample, polygon.
///
/// UI strings live in [SecurityLocalization] (or your layer); this service only
/// returns [GeoFenceOutcome]. Polygon vertices use a **buffer zone** — see
/// [campusPolygon] in [campus_geo_constants.dart].
class GeoFenceService {
  GeoFenceService._();
  static final GeoFenceService instance = GeoFenceService._();

  /// `true` only when [evaluateCampusBoundary] returns [GeoFenceOutcome.inside].
  Future<bool> isInsideCampus() async =>
      (await evaluateCampusBoundary()) == GeoFenceOutcome.inside;

  /// One-shot check used before Security Gate NFC: inside polygon or a failure code.
  Future<GeoFenceOutcome> evaluateCampusBoundary() async {
    if (kIsWeb) {
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 25),
        ),
      );

      final inside = pointInCampusPolygon(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return inside ? GeoFenceOutcome.inside : GeoFenceOutcome.outsideCampus;
    } on TimeoutException {
      return GeoFenceOutcome.locationUnavailable;
    } catch (e, st) {
      debugPrint('[GeoFenceService] evaluateCampusBoundary failed: $e');
      debugPrintStack(label: '[GeoFenceService] stack', stackTrace: st);
      return GeoFenceOutcome.locationUnavailable;
    }
  }

  /// Ray casting: odd number of intersections ⇒ inside (WGS84, small-area flatness).
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
