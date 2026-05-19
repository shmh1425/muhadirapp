import '../../models/attendance/manual_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../lecturer/lecture_repository.dart';
import 'manual_attendance_service.dart';

/// Term-wide scheduled lecture expansion + default-present persistence for reports.
class AttendanceReportTermService {
  AttendanceReportTermService._();
  static final AttendanceReportTermService instance =
      AttendanceReportTermService._();

  final ManualAttendanceService _manual = ManualAttendanceService.instance;

  /// Ensures ended scheduled lectures without an opened session have persisted
  /// default-present sessions, then returns all section sessions.
  Future<List<ManualAttendanceSession>> syncAndLoadSectionSessions({
    required List<LectureItem> lectures,
    required LectureRepository calendar,
  }) async {
    final sectionIds = <String>{
      for (final l in lectures)
        if ((l.sectionId ?? '').trim().isNotEmpty) (l.sectionId ?? '').trim(),
    };
    if (sectionIds.isEmpty) return const <ManualAttendanceSession>[];

    final existing =
        await _manual.getSessionsForSectionIds(sectionIds);
    final knownSessionIds = existing.map((s) => s.sessionId).toSet();
    final now = calendar.currentDateTime;

    for (final lecture in lectures) {
      final sectionId = (lecture.sectionId ?? '').trim();
      if (sectionId.isEmpty) continue;

      final maxWeek = calendar.manageLecturesWeekUpperBound;
      for (var week = 1; week <= maxWeek; week++) {
        final date = calendar.dateForOfficialWeekAndWeekday(
          week,
          lecture.dayOfWeek,
        );
        if (date == null) continue;
        if (!calendar.isWithinActiveTerm(date)) continue;
        if (calendar.isScheduledLecturesExcluded(date)) continue;
        if (_manual.isLectureStillOpenForReporting(lecture, date, now: now)) {
          continue;
        }

        final sessionId = ManualAttendanceService.buildSessionId(
          sectionId: sectionId,
          sessionDate: date,
          lectureStartTime: lecture.startTime,
        );
        if (knownSessionIds.contains(sessionId)) continue;

        final created = await _manual.ensureDefaultPresentSessionForEndedLecture(
          lecture: lecture,
          lectureDate: date,
          now: now,
        );
        if (created != null && created.isNotEmpty) {
          knownSessionIds.add(created);
        }
      }
    }

    return _manual.getSessionsForSectionIds(sectionIds);
  }
}
