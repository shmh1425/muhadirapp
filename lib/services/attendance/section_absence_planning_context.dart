/// Authoritative inputs for absence % denominator (shared student + lecturer).
///
/// Source of truth:
/// - [weeklyMinutesFromSectionSchedule] from Firestore `sections/{id}.schedule`
/// - [semesterTeachingWeeks] from Firestore `academic_terms.effectiveTeachingWeeks`
///   (via [AcademicTermContextRepository])
class SectionAbsencePlanningContext {
  const SectionAbsencePlanningContext({
    required this.sectionId,
    required this.courseCode,
    required this.weeklyMinutesFromSectionSchedule,
    required this.semesterTeachingWeeks,
    this.weeklyMinutesFromCourseFallback = 0,
  });

  final String sectionId;
  final String courseCode;

  /// Firestore `sections.schedule` → sum of slot durations (minutes per week).
  final int weeklyMinutesFromSectionSchedule;

  /// Firestore `academic_terms.effectiveTeachingWeeks` (clamped 1–40, default 15).
  final int semesterTeachingWeeks;

  /// Only used when section schedule has no usable slots (`courses.weeklyHours` etc.).
  final int weeklyMinutesFromCourseFallback;

  /// Weekly minutes for [AttendanceStudentCardCalculator] (section schedule first).
  int get effectiveWeeklyMinutes => weeklyMinutesFromSectionSchedule > 0
      ? weeklyMinutesFromSectionSchedule
      : weeklyMinutesFromCourseFallback;

  Map<String, int> get codeToWeeklyMinutes {
    final code = courseCode.trim();
    if (code.isEmpty) return const <String, int>{};
    final weekly = effectiveWeeklyMinutes;
    if (weekly <= 0) return const <String, int>{};
    return <String, int>{code: weekly};
  }
}
