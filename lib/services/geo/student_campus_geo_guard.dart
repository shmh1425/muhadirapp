import 'package:flutter/foundation.dart';

import '../../features/translation/translation_controller.dart';
import 'campus_geo_check_mode.dart';
import 'campus_geo_registry.dart';
import 'campus_geo_schedule_resolver.dart';
import 'geo_fence_outcome.dart';
import 'geo_fence_service.dart';

/// Geo-fence for students.
class StudentCampusGeoGuard {
  StudentCampusGeoGuard._();

  /// Debug / QA only: skip attendance geo-fence for QR. NFC and Bluetooth have no geo-fence.
  static final ValueNotifier<bool> debugSkipAttendanceGeoFence =
      ValueNotifier<bool>(false);

  static const Duration _gateCacheTtl = Duration(seconds: 90);
  static bool _gateCacheValid = false;
  static DateTime? _gateCacheAt;
  static GeoFenceOutcome? _gateCachedBlocking;
  static Future<GeoFenceOutcome?>? _gateCheckInFlight;

  /// Whether today's timetable requires attendance geo-fence (العابدية only).
  static Future<bool> attendanceGeoRequiredToday() async {
    if (debugSkipAttendanceGeoFence.value) return false;
    if (kIsWeb) return false;
    final ids = await CampusGeoScheduleResolver.campusIdsFromSchedule(
      CampusGeoCheckMode.todaySchedule,
    );
    return ids.isNotEmpty;
  }

  /// `null` = allowed; otherwise the student must not proceed.
  static Future<GeoFenceOutcome?> blockingOutcome({
    CampusGeoCheckMode mode = CampusGeoCheckMode.todaySchedule,
  }) async {
    if (kIsWeb) return null;

    final isGate = mode == CampusGeoCheckMode.girlsSecurityGate;
    if (!isGate && debugSkipAttendanceGeoFence.value) return null;
    if (isGate) {
      final cached = _readGateCache();
      if (cached.hit) return cached.blocking;
      _gateCheckInFlight ??= _evaluate(mode);
      try {
        return await _gateCheckInFlight!;
      } finally {
        _gateCheckInFlight = null;
      }
    }

    return _evaluate(mode);
  }

  static Future<GeoFenceOutcome?> _evaluate(CampusGeoCheckMode mode) async {
    final isGate = mode == CampusGeoCheckMode.girlsSecurityGate;

    final List<CampusGeoDefinition> campuses;
    if (isGate) {
      campuses = CampusGeoRegistry.gateGeoFenceCampuses
          .where((c) => c.hasPolygon)
          .toList();
    } else {
      final campusIds =
          await CampusGeoScheduleResolver.campusIdsFromSchedule(mode);
      if (campusIds.isEmpty) return null;
      campuses = CampusGeoRegistry.definitionsForCampusIds(campusIds)
          .where((c) => c.hasPolygon)
          .toList();
    }
    if (campuses.isEmpty) return null;

    final outcome = await GeoFenceService.instance.evaluateCampusBoundaries(
      polygons: campuses.map((c) => c.polygon).toList(),
      bufferMeters: isGate ? GeoFenceService.gateGpsBufferMeters : 0,
      preferGateAccuracy: isGate,
    );

    final blocking = outcome == GeoFenceOutcome.inside ? null : outcome;
    if (isGate) {
      _writeGateCache(blocking);
    }
    return blocking;
  }

  static ({bool hit, GeoFenceOutcome? blocking}) _readGateCache() {
    final at = _gateCacheAt;
    if (!_gateCacheValid || at == null) {
      return (hit: false, blocking: null);
    }
    if (DateTime.now().difference(at) > _gateCacheTtl) {
      _gateCacheValid = false;
      _gateCacheAt = null;
      _gateCachedBlocking = null;
      return (hit: false, blocking: null);
    }
    return (hit: true, blocking: _gateCachedBlocking);
  }

  static void _writeGateCache(GeoFenceOutcome? blocking) {
    _gateCacheValid = true;
    _gateCacheAt = DateTime.now();
    _gateCachedBlocking = blocking;
  }

  /// Call after a false "outside campus" when the user is visibly on campus.
  static void invalidateGateCache() {
    _gateCacheValid = false;
    _gateCacheAt = null;
    _gateCachedBlocking = null;
    _gateCheckInFlight = null;
  }

  static String localizedMessage(
    GeoFenceOutcome outcome, {
    CampusGeoCheckMode mode = CampusGeoCheckMode.todaySchedule,
  }) {
    final en = TranslationController.instance.translateToEnglish;

    switch (outcome) {
      case GeoFenceOutcome.inside:
        return en ? 'Inside campus.' : 'داخل نطاق الحرم.';
      case GeoFenceOutcome.outsideCampus:
        if (mode == CampusGeoCheckMode.girlsSecurityGate) {
          return _girlsGateOutsideCampusMessage(en);
        }
        return en
            ? 'You are outside the university campus boundary. Attendance is blocked until you enter the allowed area.'
            : 'أنت خارج حدود الحرم الجامعي. لا يمكن تسجيل الحضور قبل الدخول إلى النطاق المسموح.';
      case GeoFenceOutcome.permissionDenied:
        return en
            ? 'Location permission is required. Enable it in device settings.'
            : 'يلزم إذن الموقع. فعّله من إعدادات الجهاز.';
      case GeoFenceOutcome.locationServiceDisabled:
        return en
            ? 'Turn on location services in device settings.'
            : 'فعّل خدمة الموقع من إعدادات الجهاز.';
      case GeoFenceOutcome.locationUnavailable:
        return en
            ? 'Unable to verify your location. Try again.'
            : 'تعذر التحقق من موقعك. حاول مرة أخرى.';
    }
  }

  static String _girlsGateOutsideCampusMessage(bool en) {
    return en
        ? 'You must be on campus to use the security gate.'
        : 'يجب أن تكون داخل الحرم الجامعي لاستخدام البوابة الأمنية.';
  }
}
