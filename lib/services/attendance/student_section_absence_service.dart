import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance/manual_attendance_record.dart';
import 'attendance_student_card_calculator.dart';
import 'section_absence_planning_context.dart';
import 'section_absence_planning_repository.dart';

/// Semester-wide absence % for a section using [manual_attendance_records]
/// and [SectionAbsencePlanningRepository] (Firestore denominators).
class StudentSectionAbsenceService {
  StudentSectionAbsenceService._();
  static final StudentSectionAbsenceService instance =
      StudentSectionAbsenceService._();

  static const String _recordsCollection = 'manual_attendance_records';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SectionAbsencePlanningRepository _planning =
      SectionAbsencePlanningRepository.instance;

  Future<SectionAbsencePlanningContext> loadPlanningForSection({
    required String sectionId,
    required String courseCode,
  }) =>
      _planning.loadForSection(sectionId: sectionId, courseCode: courseCode);

  Future<Map<String, SectionAbsencePlanningContext>> loadPlanningForSections(
    Map<String, String> sectionIdToCourseCode,
  ) =>
      _planning.loadForSections(sectionIdToCourseCode);

  Future<int> loadSemesterTeachingWeeks() =>
      _planning.loadSemesterTeachingWeeks();

  Future<List<Map<String, dynamic>>> fetchSectionRecordMaps(String sectionId) =>
      _fetchSectionRecordMaps(sectionId);

  Future<List<Map<String, dynamic>>> _fetchSectionRecordMaps(
    String sectionId,
  ) async {
    final raw = sectionId.trim();
    if (raw.isEmpty) return const <Map<String, dynamic>>[];

    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    final snapshots = <QuerySnapshot<Map<String, dynamic>>>[];

    snapshots.add(
      await _firestore
          .collection(_recordsCollection)
          .where('sectionId', isEqualTo: raw)
          .get(),
    );
    if (normalized != raw) {
      snapshots.add(
        await _firestore
            .collection(_recordsCollection)
            .where('sectionId', isEqualTo: normalized)
            .get(),
      );
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final snap in snapshots) {
      for (final doc in snap.docs) {
        byId[doc.id] = doc.data();
      }
    }
    return byId.values.toList();
  }

  static Map<String, dynamic> mapFromManualRecord(ManualAttendanceRecord r) {
    return <String, dynamic>{
      'status': ManualAttendanceRecord.statusToString(r.status),
      'sectionId': r.sectionId,
      'courseCode': r.courseCode ?? '',
      'courseName': r.courseName,
      'lectureStartTime': r.lectureStartTime,
      'lectureEndTime': r.lectureEndTime,
      'lectureYear': r.lectureDate.year,
      'lectureMonth': r.lectureDate.month,
      'lectureDay': r.lectureDate.day,
      'lectureDate': Timestamp.fromDate(
        DateTime(
          r.lectureDate.year,
          r.lectureDate.month,
          r.lectureDate.day,
        ),
      ),
    };
  }

  static List<Map<String, dynamic>> mapsFromUiRecords(
    Iterable<({
      String status,
      String? sectionId,
      String? courseCode,
      String courseName,
      String timeRange,
      DateTime lectureDate,
      String courseKey,
    })> records,
  ) {
    return records.map((r) {
      final parts = r.timeRange.split('-');
      final start = parts.isNotEmpty ? parts[0].trim() : '';
      final end = parts.length > 1 ? parts[1].trim() : '';
      return <String, dynamic>{
        'status': r.status == 'unexcused' ? 'absent' : r.status,
        'sectionId': r.sectionId ?? '',
        'courseCode': r.courseCode ?? '',
        'courseName': r.courseName,
        'lectureStartTime': start,
        'lectureEndTime': end,
        'lectureYear': r.lectureDate.year,
        'lectureMonth': r.lectureDate.month,
        'lectureDay': r.lectureDate.day,
        'lectureDate': Timestamp.fromDate(
          DateTime(
            r.lectureDate.year,
            r.lectureDate.month,
            r.lectureDate.day,
          ),
        ),
      };
    }).toList();
  }

  AbsenceCardPercentages computeCardPercentages({
    required List<Map<String, dynamic>> records,
    required Map<String, SectionAbsencePlanningContext> planningBySectionId,
    required Iterable<String> sectionIdsForWeekly,
    required String primaryCourseCode,
    required int semesterWeeksCount,
  }) {
    final codeToWeekly =
        SectionAbsencePlanningRepository.mergeCodeToWeeklyMinutes(
      planningBySectionId,
    );
    final weekly = SectionAbsencePlanningRepository.resolveWeeklyMinutes(
      sectionIds: sectionIdsForWeekly,
      planningBySectionId: planningBySectionId,
      codeToWeeklyMinutes: codeToWeekly,
      primaryCourseCode: primaryCourseCode,
    );
    return AttendanceStudentCardCalculator.computeCardPercentages(
      records: records,
      weeklyMinutesFromSection: weekly,
      codeToWeeklyMinutes: codeToWeekly,
      courseCode: primaryCourseCode,
      semesterWeeksCount: semesterWeeksCount,
    );
  }

  /// Overall section absence metrics per student (shared calculator + deprivation flag).
  Future<Map<int, StudentSectionAbsenceMetrics>> loadAbsenceMetricsByStudentId({
    required String sectionId,
    required String courseCode,
  }) async {
    final section = sectionId.trim();
    if (section.isEmpty) return const <int, StudentSectionAbsenceMetrics>{};

    final planning = await _planning.loadForSection(
      sectionId: section,
      courseCode: courseCode,
    );
    final allMaps = await _fetchSectionRecordMaps(section);
    if (allMaps.isEmpty) return const <int, StudentSectionAbsenceMetrics>{};

    final byStudent = <int, List<Map<String, dynamic>>>{};
    for (final data in allMaps) {
      final sid = _safeInt(data['studentId']);
      if (sid <= 0) continue;
      byStudent.putIfAbsent(sid, () => <Map<String, dynamic>>[]).add(data);
    }

    final out = <int, StudentSectionAbsenceMetrics>{};
    for (final entry in byStudent.entries) {
      out[entry.key] = AttendanceStudentCardCalculator.metricsFromRecords(
        records: entry.value,
        weeklyMinutesFromSection: planning.weeklyMinutesFromSectionSchedule,
        codeToWeeklyMinutes: planning.codeToWeeklyMinutes,
        courseCode: courseCode,
        semesterWeeksCount: planning.semesterTeachingWeeks,
      );
    }
    return out;
  }

  /// Display floor only — prefer [loadAbsenceMetricsByStudentId] when deprivation is needed.
  Future<Map<int, int>> loadTotalAbsencePercentByStudentId({
    required String sectionId,
    required String courseCode,
  }) async {
    final metrics = await loadAbsenceMetricsByStudentId(
      sectionId: sectionId,
      courseCode: courseCode,
    );
    return {
      for (final e in metrics.entries) e.key: e.value.displayPercentFloor,
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
