import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lecturer_catalog_providers.dart';
import '../attendance/manual_attendance_service.dart';
import '../lecturer_auth_service.dart';
import 'lecturer_attendance_sessions_warm_cache.dart';
import 'lecture_repository.dart';

/// Background prefetch after lecturer login / shell open: catalog, calendar, session docs only.
class LecturerColdStartWarmup {
  LecturerColdStartWarmup._();

  static Future<void>? _inFlight;
  static String? _inFlightLecturerId;

  /// Idempotent per lecturer: concurrent callers share one in-flight warmup.
  static Future<void> run(ProviderContainer container) {
    final id =
        (LecturerAuthService.instance.currentLecturer?.lecturerId ?? '').trim();
    if (id.isEmpty) return Future.value();

    if (_inFlight != null && _inFlightLecturerId == id) {
      return _inFlight!;
    }
    final flight = _run(container, id);
    _inFlightLecturerId = id;
    _inFlight = flight.whenComplete(() {
      if (_inFlightLecturerId == id) {
        _inFlight = null;
        _inFlightLecturerId = null;
      }
    });
    return _inFlight!;
  }

  static Future<void> _run(ProviderContainer container, String lecturerId) async {
    final calendarRepo = LectureRepository();
    try {
      await Future.wait<Object?>([
        calendarRepo.refreshAcademicCalendar().timeout(
          const Duration(seconds: 6),
          onTimeout: () {},
        ),
        container.read(lecturerUnifiedCatalogProvider.future),
      ]);
    } catch (e, st) {
      debugPrint('[LecturerColdStartWarmup] catalog/calendar: $e');
      debugPrint('$st');
      try {
        await container.read(lecturerUnifiedCatalogProvider.future);
      } catch (e2) {
        debugPrint('[LecturerColdStartWarmup] catalog retry: $e2');
        return;
      }
    }

    final catalog =
        container.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (catalog == null || catalog.isEmpty) return;

    final sectionIds = catalog.sectionIds;
    if (sectionIds.isEmpty) return;

    try {
      final sessions = await ManualAttendanceService.instance
          .getSessionsForSectionIds(sectionIds)
          .timeout(const Duration(seconds: 30));
      LecturerAttendanceSessionsWarmCache.store(
        lecturerId: lecturerId,
        sectionIds: sectionIds,
        sessions: sessions,
      );
    } catch (e) {
      debugPrint('[LecturerColdStartWarmup] sessions prefetch: $e');
    }
  }
}
