import 'course_model.dart';
import 'course_weekly_slot.dart';

/// Single in-memory view of a student's courses for shared UI state.
///
/// Built only from [CourseModel] rows (repository / Hive); no Firestore.
class UnifiedStudentCourses {
  const UnifiedStudentCourses({
    required this.allCourses,
    required this.todayCourses,
    required this.scheduleCourses,
  });

  final List<CourseModel> allCourses;

  /// Enrollments that have at least one weekly slot on the current weekday
  /// (local time), empty when [isHoliday] was true at build time.
  final List<CourseModel> todayCourses;

  /// [allCourses] sorted for stable schedule UI (display name, then code).
  final List<CourseModel> scheduleCourses;

  static UnifiedStudentCourses empty() => const UnifiedStudentCourses(
        allCourses: <CourseModel>[],
        todayCourses: <CourseModel>[],
        scheduleCourses: <CourseModel>[],
      );

  /// Pure transformation: no I/O.
  factory UnifiedStudentCourses.fromCourses(
    List<CourseModel> all, {
    required bool isHoliday,
  }) {
    if (all.isEmpty) {
      return UnifiedStudentCourses.empty();
    }

    String displaySortKey(CourseModel c) {
      final ar = c.courseNameAr.trim();
      final en = c.courseNameEn.trim();
      final code = c.courseCode.trim();
      final primary = ar.isNotEmpty ? ar : (en.isNotEmpty ? en : code);
      return primary.toLowerCase();
    }

    final scheduleCourses = List<CourseModel>.from(all)
      ..sort((a, b) {
        final ka = displaySortKey(a);
        final kb = displaySortKey(b);
        final c = ka.compareTo(kb);
        if (c != 0) return c;
        return a.sectionId.compareTo(b.sectionId);
      });

    if (isHoliday) {
      return UnifiedStudentCourses(
        allCourses: List<CourseModel>.from(all),
        todayCourses: const <CourseModel>[],
        scheduleCourses: scheduleCourses,
      );
    }

    final todayWeekday = DateTime.now().weekday;
    final today = <CourseModel>[];
    for (final c in all) {
      if (c.weeklySlots.any((s) => s.dayOfWeek == todayWeekday)) {
        today.add(c);
      }
    }

    String firstSlotStart(CourseModel c) {
      for (final s in c.weeklySlots) {
        if (s.dayOfWeek == todayWeekday) return s.normalizedStartTime;
      }
      return '';
    }

    today.sort((a, b) => firstSlotStart(a).compareTo(firstSlotStart(b)));

    return UnifiedStudentCourses(
      allCourses: List<CourseModel>.from(all),
      todayCourses: today,
      scheduleCourses: scheduleCourses,
    );
  }

  /// Each (model, slot) for today's weekday — sorted by start time — for home cards.
  List<({CourseModel model, CourseWeeklySlot slot})> todaySlotRows() {
    if (todayCourses.isEmpty) return const [];
    final w = DateTime.now().weekday;
    final rows = <({CourseModel model, CourseWeeklySlot slot})>[];
    for (final m in todayCourses) {
      for (final s in m.weeklySlots) {
        if (s.dayOfWeek == w) {
          rows.add((model: m, slot: s));
        }
      }
    }
    rows.sort((a, b) =>
        a.slot.normalizedStartTime.compareTo(b.slot.normalizedStartTime));
    return rows;
  }
}
