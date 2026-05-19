import 'package:cloud_firestore/cloud_firestore.dart';

import '../../repositories/academic_term_context_repository.dart';
import 'attendance_planned_summary.dart';
import 'section_absence_planning_context.dart';

/// Single source of truth for absence-% denominators (student + lecturer).
class SectionAbsencePlanningRepository {
  SectionAbsencePlanningRepository._();
  static final SectionAbsencePlanningRepository instance =
      SectionAbsencePlanningRepository._();

  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// `academic_terms.effectiveTeachingWeeks` (default 15).
  Future<int> loadSemesterTeachingWeeks() async {
    final ctx =
        await AcademicTermContextRepository.instance.loadCurrentWeekContext();
    if (ctx != null && ctx.weeks > 0) {
      return ctx.weeks.clamp(1, 40);
    }
    return 15;
  }

  Future<SectionAbsencePlanningContext> loadForSection({
    required String sectionId,
    required String courseCode,
    int? semesterTeachingWeeks,
  }) async {
    final section = sectionId.trim();
    final code = courseCode.trim();
    final weeks =
        semesterTeachingWeeks ?? await loadSemesterTeachingWeeks();

    var weeklyFromSchedule = 0;
    if (section.isNotEmpty) {
      try {
        final snap =
            await _firestore.collection(_sectionsCollection).doc(section).get();
        if (snap.exists) {
          final schedule = snap.data()?['schedule'];
          weeklyFromSchedule =
              AttendancePlannedSummary.weeklyMinutesFromSectionSchedule(
            schedule is List<dynamic> ? schedule : null,
          );
        }
      } catch (_) {}
    }

    var weeklyFromCourse = 0;
    if (code.isNotEmpty) {
      try {
        final courseSnap =
            await _firestore.collection(_coursesCollection).doc(code).get();
        if (courseSnap.exists) {
          weeklyFromCourse =
              AttendancePlannedSummary.weeklyMinutesFromCourseMap(
            courseSnap.data(),
          );
        }
      } catch (_) {}
    }

    return SectionAbsencePlanningContext(
      sectionId: section,
      courseCode: code,
      weeklyMinutesFromSectionSchedule: weeklyFromSchedule,
      semesterTeachingWeeks: weeks,
      weeklyMinutesFromCourseFallback: weeklyFromSchedule > 0 ? 0 : weeklyFromCourse,
    );
  }

  /// Batch load by section id → course code (parallel).
  Future<Map<String, SectionAbsencePlanningContext>> loadForSections(
    Map<String, String> sectionIdToCourseCode,
  ) async {
    final entries = sectionIdToCourseCode.entries
        .where((e) => e.key.trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) return const <String, SectionAbsencePlanningContext>{};

    final weeks = await loadSemesterTeachingWeeks();
    final contexts = await Future.wait(
      entries.map(
        (e) => loadForSection(
          sectionId: e.key,
          courseCode: e.value,
          semesterTeachingWeeks: weeks,
        ),
      ),
    );
    return {for (final c in contexts) c.sectionId: c};
  }

  /// Same priority as legacy student card: max section schedule weekly across sections.
  static int resolveWeeklyMinutes({
    required Iterable<String> sectionIds,
    required Map<String, SectionAbsencePlanningContext> planningBySectionId,
    required Map<String, int> codeToWeeklyMinutes,
    required String primaryCourseCode,
  }) {
    var weekly = 0;
    for (final raw in sectionIds) {
      final sid = raw.trim();
      if (sid.isEmpty) continue;
      final ctx = planningBySectionId[sid];
      if (ctx != null) {
        final w = ctx.effectiveWeeklyMinutes;
        if (w > weekly) weekly = w;
      }
    }
    if (weekly <= 0) {
      final code = primaryCourseCode.trim();
      if (code.isNotEmpty) {
        weekly = codeToWeeklyMinutes[code] ?? 0;
      }
    }
    if (weekly <= 0) {
      for (final ctx in planningBySectionId.values) {
        final w = ctx.effectiveWeeklyMinutes;
        if (w > weekly) weekly = w;
      }
    }
    return weekly;
  }

  static Map<String, int> mergeCodeToWeeklyMinutes(
    Map<String, SectionAbsencePlanningContext> planningBySectionId,
  ) {
    final out = <String, int>{};
    for (final ctx in planningBySectionId.values) {
      for (final e in ctx.codeToWeeklyMinutes.entries) {
        final prev = out[e.key] ?? 0;
        if (e.value > prev) out[e.key] = e.value;
      }
    }
    return out;
  }
}
