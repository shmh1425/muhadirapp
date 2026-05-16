import '../../models/course_model.dart';
import '../../models/course_weekly_slot.dart';
import '../../repositories/student_repository.dart';
import '../../services/student_auth_service.dart';
import 'campus_geo_check_mode.dart';
import 'campus_geo_registry.dart';

/// Resolves campus branch ids from the student **timetable** (attendance only).
class CampusGeoScheduleResolver {
  CampusGeoScheduleResolver._();

  static Future<Set<String>> campusIdsFromSchedule(CampusGeoCheckMode mode) async {
    assert(mode != CampusGeoCheckMode.girlsSecurityGate);
    switch (mode) {
      case CampusGeoCheckMode.girlsSecurityGate:
        return <String>{};
      case CampusGeoCheckMode.todaySchedule:
        return _campusIdsFromCourses(
          await _loadCourses(),
          onlyWeekday: DateTime.now().weekday,
        );
      case CampusGeoCheckMode.allSchedule:
        return _campusIdsFromCourses(await _loadCourses());
    }
  }

  static Future<List<CourseModel>> _loadCourses() async {
    final sid =
        StudentAuthService.instance.currentStudent?.studentId.toString() ?? '';
    if (sid.isEmpty) return const <CourseModel>[];

    final cached = StudentRepository().getCachedCourses(sid);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      return await StudentRepository()
          .getStudentCourses(sid)
          .timeout(const Duration(seconds: 8), onTimeout: () => cached ?? const []);
    } catch (_) {
      return cached ?? const <CourseModel>[];
    }
  }

  static Set<String> _campusIdsFromCourses(
    List<CourseModel> courses, {
    int? onlyWeekday,
  }) {
    final ids = <String>{};
    for (final course in courses) {
      for (final CourseWeeklySlot slot in course.weeklySlots) {
        if (onlyWeekday != null && slot.dayOfWeek != onlyWeekday) continue;
        final campusId = CampusGeoRegistry.campusIdForScheduleLocation(
          slot.location,
        );
        if (campusId != null) ids.add(campusId);
      }
    }
    return ids;
  }
}
