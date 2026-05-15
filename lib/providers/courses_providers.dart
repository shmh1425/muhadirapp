import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mappers/course_model_to_schedule.dart';
import '../models/course_schedule.dart';
import '../models/course_model.dart';
import '../models/unified_student_courses.dart';
import '../repositories/academic_calendar_repository.dart';
import '../repositories/student_repository.dart';

/// Injectable [StudentRepository] (stateless aside from Hive/Firestore clients).
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository();
});

/// Single source of truth: repository (Hive-first) + in-memory splits + holiday.
///
/// Does not call Firestore directly; calendar uses [AcademicCalendarRepository].
final studentUnifiedCoursesProvider =
    FutureProvider.family<UnifiedStudentCourses, String>((ref, studentId) async {
  final trimmed = studentId.trim();
  if (trimmed.isEmpty) return UnifiedStudentCourses.empty();
  final repo = ref.watch(studentRepositoryProvider);
  // Avoid indefinite loading if Firestore never completes (offline / hung request).
  List<CourseModel> all;
  try {
    all = await repo.getStudentCourses(trimmed).timeout(
          const Duration(seconds: 15),
          onTimeout: () => <CourseModel>[],
        );
  } catch (_) {
    all = <CourseModel>[];
  }
  // Do not block the whole student UI on calendar I/O (can stall on slow/offline networks).
  var isHoliday = false;
  try {
    isHoliday = await AcademicCalendarRepository.instance
        .isHolidayForStudent(DateTime.now())
        .timeout(const Duration(seconds: 4), onTimeout: () => false);
  } catch (_) {
    isHoliday = false;
  }
  return UnifiedStudentCourses.fromCourses(all, isHoliday: isHoliday);
});

/// Back-compat: all enrollments from [studentUnifiedCoursesProvider].
final studentCoursesProvider =
    FutureProvider.family<List<CourseModel>, String>((ref, studentId) async {
  final u = await ref.watch(studentUnifiedCoursesProvider(studentId).future);
  return u.allCourses;
});

/// Weekly grid rows derived in-memory from [UnifiedStudentCourses.scheduleCourses].
final studentScheduleGridProvider =
    FutureProvider.family<List<CourseSchedule>, String>((ref, studentId) async {
  final u = await ref.watch(studentUnifiedCoursesProvider(studentId).future);
  return courseModelsToScheduleGrid(u.scheduleCourses);
});
