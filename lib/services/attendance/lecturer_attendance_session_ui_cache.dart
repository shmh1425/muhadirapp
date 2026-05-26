/// In-memory UI cache for lecturer live attendance (survives screen dispose).
///
/// Keyed by [ManualAttendanceSession] id so re-entering the same lecture does not
/// show a full-screen loader while Firestore catches up.
class LecturerAttendanceSessionUiCache {
  LecturerAttendanceSessionUiCache._();
  static final LecturerAttendanceSessionUiCache instance =
      LecturerAttendanceSessionUiCache._();

  final Map<String, LecturerAttendanceSessionSnapshot> _bySession =
      <String, LecturerAttendanceSessionSnapshot>{};

  LecturerAttendanceSessionSnapshot? snapshotFor(String sessionId) {
    final key = sessionId.trim();
    if (key.isEmpty) return null;
    return _bySession[key];
  }

  void put({
    required String sessionId,
    required List<LecturerCachedStudentRow> students,
    bool rosterFallback = false,
  }) {
    final key = sessionId.trim();
    if (key.isEmpty || students.isEmpty) return;
    _bySession[key] = LecturerAttendanceSessionSnapshot(
      sessionId: key,
      students: List<LecturerCachedStudentRow>.from(students),
      rosterFallback: rosterFallback,
      cachedAt: DateTime.now(),
    );
  }

  void clearSession(String sessionId) {
    final key = sessionId.trim();
    if (key.isEmpty) return;
    _bySession.remove(key);
  }
}

class LecturerAttendanceSessionSnapshot {
  const LecturerAttendanceSessionSnapshot({
    required this.sessionId,
    required this.students,
    required this.rosterFallback,
    required this.cachedAt,
  });

  final String sessionId;
  final List<LecturerCachedStudentRow> students;
  final bool rosterFallback;
  final DateTime cachedAt;
}

/// Serializable student row for session UI cache (no widget types).
class LecturerCachedStudentRow {
  const LecturerCachedStudentRow({
    required this.id,
    required this.name,
    required this.academicNumber,
    required this.attendanceTime,
    required this.percentage,
    required this.statusName,
    required this.isOffline,
    required this.uiSyncStateName,
    required this.isAcademicallyDeprived,
    this.isSuspended,
  });

  final String id;
  final String name;
  final String academicNumber;
  final String attendanceTime;
  final int percentage;
  final String statusName;
  final bool isOffline;
  final String uiSyncStateName;
  final bool isAcademicallyDeprived;
  final bool? isSuspended;
}
