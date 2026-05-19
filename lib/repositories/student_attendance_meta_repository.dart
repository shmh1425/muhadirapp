import '../models/attendance_schedule_slot.dart';
import '../models/attendance/manual_attendance_record.dart';
import '../models/course_model.dart';
import '../models/course_weekly_slot.dart';
import '../services/attendance/attendance_planned_summary.dart';

/// In-memory maps for attendance UI derived from [CourseModel] (Hive / unified path).
///
/// Schedule labels/slots only — **absence % denominators** use
/// [SectionAbsencePlanningRepository] (Firestore `sections.schedule`), not these maps.
class StudentAttendanceMetaRepository {
  StudentAttendanceMetaRepository._();
  static final StudentAttendanceMetaRepository instance =
      StudentAttendanceMetaRepository._();

  /// Same formula as Firestore `sections.schedule` via
  /// [AttendancePlannedSummary.weeklyMinutesFromSectionSchedule] (Hive cache must match).
  static int weeklyMinutesFromSlots(List<CourseWeeklySlot> slots) {
    if (slots.isEmpty) return 0;
    final schedule = slots
        .map(
          (w) => <String, dynamic>{
            'dayOfWeek': w.dayOfWeek,
            'startTime': w.normalizedStartTime,
            'endTime': w.normalizedEndTime,
          },
        )
        .toList();
    return AttendancePlannedSummary.weeklyMinutesFromSectionSchedule(schedule);
  }

  /// Same tuple shape as legacy `_fetchCourseMetaForRecords` return type.
  ({
    Map<String, String> codeToType,
    Map<String, String> sectionIdToType,
    Map<String, String> codeToNameAr,
    Map<String, int> codeToWeeklyMinutes,
    Map<String, int> sectionIdToWeeklyMinutes,
    Map<String, List<AttendanceScheduleSlot>> sectionIdToScheduleSlots,
  })
  buildFromEnrollments(
    List<CourseModel> enrollments,
    List<ManualAttendanceRecord> records,
  ) {
    final needSectionType = records
        .where((r) => (r.courseType ?? '').trim().isEmpty)
        .map((r) => r.sectionId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final codeToType = <String, String>{};
    final sectionIdToType = <String, String>{};
    final codeToNameAr = <String, String>{};
    final codeToWeeklyMinutes = <String, int>{};
    final sectionIdToWeeklyMinutes = <String, int>{};
    final sectionIdToScheduleSlots =
        <String, List<AttendanceScheduleSlot>>{};

    if (enrollments.isEmpty) {
      return (
        codeToType: codeToType,
        sectionIdToType: sectionIdToType,
        codeToNameAr: codeToNameAr,
        codeToWeeklyMinutes: codeToWeeklyMinutes,
        sectionIdToWeeklyMinutes: sectionIdToWeeklyMinutes,
        sectionIdToScheduleSlots: sectionIdToScheduleSlots,
      );
    }

    final bySection = <String, CourseModel>{};
    for (final m in enrollments) {
      final sid = m.sectionId.trim();
      if (sid.isEmpty) continue;
      bySection[sid] = m;
    }

    for (final e in bySection.entries) {
      final sid = e.key;
      final m = e.value;
      final mins = weeklyMinutesFromSlots(m.weeklySlots);
      if (mins > 0) {
        sectionIdToWeeklyMinutes[sid] = mins;
      }
      if (m.weeklySlots.isNotEmpty) {
        sectionIdToScheduleSlots[sid] = m.weeklySlots
            .map(
              (w) => AttendanceScheduleSlot(
                dayOfWeek: w.dayOfWeek,
                startTime: w.normalizedStartTime,
                endTime: w.normalizedEndTime,
              ),
            )
            .toList();
      }
      final t = m.courseType.trim();
      if (t.isNotEmpty && needSectionType.contains(sid)) {
        sectionIdToType[sid] = t;
      }
    }

    final byCode = <String, List<CourseModel>>{};
    for (final m in enrollments) {
      final c = m.courseCode.trim();
      if (c.isEmpty) continue;
      byCode.putIfAbsent(c, () => <CourseModel>[]).add(m);
    }

    for (final e in byCode.entries) {
      final code = e.key;
      final models = e.value;
      for (final m in models) {
        if (m.courseType.trim().isNotEmpty) {
          codeToType[code] = m.courseType.trim();
          break;
        }
      }
      for (final m in models) {
        if (m.courseNameAr.trim().isNotEmpty) {
          codeToNameAr[code] = m.courseNameAr.trim();
          break;
        }
      }
      var maxWeekly = 0;
      for (final m in models) {
        final w = weeklyMinutesFromSlots(m.weeklySlots);
        if (w > maxWeekly) maxWeekly = w;
      }
      if (maxWeekly > 0) {
        codeToWeeklyMinutes[code] = maxWeekly;
      }
    }

    return (
      codeToType: codeToType,
      sectionIdToType: sectionIdToType,
      codeToNameAr: codeToNameAr,
      codeToWeeklyMinutes: codeToWeeklyMinutes,
      sectionIdToWeeklyMinutes: sectionIdToWeeklyMinutes,
      sectionIdToScheduleSlots: sectionIdToScheduleSlots,
    );
  }
}
