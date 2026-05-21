/// Per-course attendance summary for AI context.
class CourseAttendanceSummary {
  const CourseAttendanceSummary({
    required this.courseName,
    required this.courseNameAr,
    required this.sectionId,
    required this.totalLectures,
    required this.weeklyScheduledHours,
    required this.totalPlannedHours,
    required this.absenceHours,
    required this.presentCount,
    required this.absentCount,
    required this.excusedCount,
    required this.absenceRate,
    required this.excusedAbsenceRate,
    required this.unexcusedAbsenceRate,
    required this.remainingHoursUnexcusedBeforeLimit,
    required this.remainingHoursExcusedBeforeLimit,
    required this.remainingHoursBeforeDeprivation,
    required this.isWarning,
    required this.isDeprivation,
  });

  final String courseName;
  final String courseNameAr;
  final String sectionId;
  /// Expected number of class sessions (lecturesPerWeek × semester weeks).
  final int totalLectures;
  /// Scheduled contact hours per week (from course/section or derived from schedule).
  final double weeklyScheduledHours;
  /// weeklyScheduledHours × semesterWeeks — denominator for absence %.
  final double totalPlannedHours;
  /// Sum of hours for sessions marked absent or excused.
  final double absenceHours;
  final int presentCount;
  final int absentCount;
  final int excusedCount;
  /// Total absence % (بعذر + بدون عذر) / المخطط.
  final double absenceRate;
  /// غياب بعذر / المخطط × 100.
  final double excusedAbsenceRate;
  /// غياب بدون عذر / المخطط × 100.
  final double unexcusedAbsenceRate;
  /// ساعات غياب «بدون عذر» المتبقية حتى بلوغ حد الحرمان (نسبة من المخطط).
  final double remainingHoursUnexcusedBeforeLimit;
  /// ساعات غياب «بعذر» المتبقية حتى بلوغ حد الحرمان (نسبة من المخطط).
  final double remainingHoursExcusedBeforeLimit;
  /// (حد الإجمالي × المخطط) − ساعات الغياب الكلية، مقيّد بين 0 والمخطط.
  final double remainingHoursBeforeDeprivation;
  final bool isWarning;
  final bool isDeprivation;

  /// Arabic label for student UI and structured chatbot replies.
  String get displayName =>
      courseNameAr.trim().isNotEmpty ? courseNameAr.trim() : courseName.trim();

  String localizedName({required bool isArabic}) {
    if (isArabic) return displayName;
    final en = courseName.trim();
    if (en.isNotEmpty) return en;
    return displayName;
  }
}

/// Full attendance context for the logged-in student (for OpenAI).
class AttendanceContext {
  const AttendanceContext({
    required this.studentId,
    required this.studentName,
    required this.universityId,
    required this.major,
    required this.todaySchedule,
    required this.weekSchedule,
    required this.currentTermName,
    required this.termStartDate,
    required this.termEndDate,
    required this.currentWeekNumber,
    required this.totalWeeks,
    required this.remainingWeeks,
    required this.coursesWithLecturers,
    required this.courses,
    required this.warningPercent,
    required this.deprivationPercent,
    required this.maxUnexcusedPercent,
    required this.rawContextString,
  });

  final String studentId;
  final String studentName;
  final String universityId;
  final String major;

  final List<Map<String, dynamic>> todaySchedule;
  final List<Map<String, dynamic>> weekSchedule;

  final String currentTermName;
  final String termStartDate;
  final String termEndDate;
  final int currentWeekNumber;
  final int totalWeeks;
  final int remainingWeeks;

  final List<Map<String, dynamic>> coursesWithLecturers;
  final List<CourseAttendanceSummary> courses;
  final int warningPercent;
  final int deprivationPercent;
  /// حد الغياب بدون عذر (نسبة من الوقت المخطط) — يُعرض للطالب وللـ AI.
  final int maxUnexcusedPercent;
  final String rawContextString;
}
