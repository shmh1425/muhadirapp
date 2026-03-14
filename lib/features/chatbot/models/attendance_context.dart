/// Per-course attendance summary for AI context.
class CourseAttendanceSummary {
  const CourseAttendanceSummary({
    required this.courseName,
    required this.courseNameAr,
    required this.sectionId,
    required this.totalLectures,
    required this.presentCount,
    required this.absentCount,
    required this.excusedCount,
    required this.absenceRate,
    required this.remainingBeforeDeprivation,
    required this.isWarning,
    required this.isDeprivation,
  });

  final String courseName;
  final String courseNameAr;
  final String sectionId;
  final int totalLectures;
  final int presentCount;
  final int absentCount;
  final int excusedCount;
  final double absenceRate;
  final int remainingBeforeDeprivation;
  final bool isWarning;
  final bool isDeprivation;

  String get displayName => courseNameAr.trim().isNotEmpty ? courseNameAr : courseName;
}

/// Full attendance context for the logged-in student (for OpenAI).
class AttendanceContext {
  const AttendanceContext({
    required this.studentId,
    required this.studentName,
    required this.courses,
    required this.warningPercent,
    required this.deprivationPercent,
    required this.rawContextString,
  });

  final String studentId;
  final String studentName;
  final List<CourseAttendanceSummary> courses;
  final int warningPercent;
  final int deprivationPercent;
  final String rawContextString;
}
