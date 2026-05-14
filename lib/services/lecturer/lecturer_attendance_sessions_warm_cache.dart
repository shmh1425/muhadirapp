import '../../models/attendance/manual_attendance_session.dart';

/// In-memory sessions list from cold-start warmup (no student records).
/// Cleared on lecturer logout.
class LecturerAttendanceSessionsWarmCache {
  LecturerAttendanceSessionsWarmCache._();

  static String? _lecturerId;
  static Set<String>? _sectionIds;
  static List<ManualAttendanceSession>? _sessions;

  static void store({
    required String lecturerId,
    required Set<String> sectionIds,
    required List<ManualAttendanceSession> sessions,
  }) {
    final id = lecturerId.trim();
    if (id.isEmpty) return;
    _lecturerId = id;
    _sectionIds = Set<String>.from(sectionIds);
    _sessions = List<ManualAttendanceSession>.from(sessions);
  }

  /// Returns a copy of warmed sessions when [sectionIds] matches exactly.
  static List<ManualAttendanceSession>? takeMatching(
    String lecturerId,
    Set<String> sectionIds,
  ) {
    final id = lecturerId.trim();
    if (id.isEmpty || _lecturerId != id || _sessions == null) return null;
    final cached = _sectionIds;
    if (cached == null) return null;
    if (cached.length != sectionIds.length) return null;
    if (!cached.containsAll(sectionIds) || !sectionIds.containsAll(cached)) {
      return null;
    }
    return List<ManualAttendanceSession>.from(_sessions!);
  }

  static void clear() {
    _lecturerId = null;
    _sectionIds = null;
    _sessions = null;
  }
}
