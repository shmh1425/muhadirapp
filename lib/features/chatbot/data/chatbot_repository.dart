import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../models/attendance/manual_attendance_record.dart';
import '../../../../services/student_auth_service.dart';
import '../models/attendance_context.dart';

/// Fetches real attendance data from Firestore for the chatbot.
class ChatbotRepository {
  ChatbotRepository._();
  static final ChatbotRepository instance = ChatbotRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _enrollmentsCollection = 'student_section_enrollments';
  static const String _sectionsCollection = 'sections';
  static const String _coursesCollection = 'courses';
  static const String _sessionsCollection = 'manual_attendance_sessions';
  static const String _recordsCollection = 'manual_attendance_records';
  static const String _academicRulesCollection = 'academic_rules';
  static const int _defaultTotalLecturesPerSection = 30;

  /// Returns attendance context for the current student, or null if not logged in / no data.
  Future<AttendanceContext?> getAttendanceContext() async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) return null;

    final studentIdStr = student.studentId.toString();
    final studentName = student.displayName;

    try {
      final enrollmentsSnap = await _firestore
          .collection(_enrollmentsCollection)
          .where('studentId', isEqualTo: student.studentId)
          .get();

      final enrollmentDocs = enrollmentsSnap.docs;
      if (enrollmentDocs.isEmpty) return null;

      int warningPercent = 15;
      int deprivationPercent = 25;
      try {
        final rulesRef =
            _firestore.collection(_academicRulesCollection).doc('default');
        final rulesDoc = await rulesRef.get();
        if (rulesDoc.exists) {
          final data = rulesDoc.data();
          if (data != null) {
            warningPercent = (data['warningPercent'] as num?)?.toInt() ?? 15;
            deprivationPercent =
                (data['maxAbsencePercent'] as num?)?.toInt() ?? 25;
          }
        } else {
          await rulesRef.set({
            'maxAbsencePercent': 25,
            'warningPercent': 15,
            'maxUnexcusedPercent': 15,
          });
        }
      } catch (_) {}

      final List<CourseAttendanceSummary> courses = [];
      final List<String> contextLines = [];

      for (final enrollDoc in enrollmentDocs) {
        final sectionId =
            (enrollDoc.data()['sectionId'] ?? '').toString().trim();
        if (sectionId.isEmpty) continue;

        final sectionDoc =
            await _firestore.collection(_sectionsCollection).doc(sectionId).get();
        if (!sectionDoc.exists) continue;

        final sectionData = sectionDoc.data() ?? {};
        final courseCode =
            (sectionData['courseCode'] ?? sectionData['courseId'] ?? '')
                .toString()
                .trim();
        final courseName =
            (sectionData['courseName'] ?? '').toString().trim();

        String courseNameAr = '';
        if (courseCode.isNotEmpty) {
          final courseDoc = await _firestore
              .collection(_coursesCollection)
              .doc(courseCode)
              .get();
          if (courseDoc.exists) {
            final courseData = courseDoc.data() ?? {};
            courseNameAr =
                (courseData['courseName_Ar'] ?? courseData['courseNameAr'] ?? '')
                    .toString()
                    .trim();
          }
        }
        final displayCourseName =
            courseNameAr.isNotEmpty ? courseNameAr : courseName;
        if (displayCourseName.isEmpty) continue;

        int totalLectures = _defaultTotalLecturesPerSection;
        final totalFromSection = sectionData['totalLectures'];
        if (totalFromSection is int && totalFromSection > 0) {
          totalLectures = totalFromSection;
        } else if (totalFromSection is num) {
          totalLectures = totalFromSection.toInt();
        } else {
          final sessionsSnap = await _firestore
              .collection(_sessionsCollection)
              .where('sectionId', isEqualTo: sectionId)
              .get();
          if (sessionsSnap.docs.isNotEmpty) {
            totalLectures = sessionsSnap.docs.length;
          }
        }

        final recordsSnap = await _firestore
            .collection(_recordsCollection)
            .where('studentId', isEqualTo: student.studentId)
            .where('sectionId', isEqualTo: sectionId)
            .get();

        int presentCount = 0;
        int absentCount = 0;
        int excusedCount = 0;

        for (final doc in recordsSnap.docs) {
          final record = ManualAttendanceRecord.fromDoc(
            doc,
          );
          switch (record.status) {
            case ManualAttendanceStatus.present:
            case ManualAttendanceStatus.late:
              presentCount++;
              break;
            case ManualAttendanceStatus.absent:
              absentCount++;
              break;
            case ManualAttendanceStatus.excused:
              excusedCount++;
              break;
          }
        }

        final totalAbsences = absentCount + excusedCount;
        final absenceRate = totalLectures > 0
            ? (totalAbsences / totalLectures) * 100
            : 0.0;
        final maxAbsences = (totalLectures * (deprivationPercent / 100)).ceil();
        final remainingBeforeDeprivation =
            (maxAbsences - totalAbsences).clamp(0, totalLectures);
        final isWarning = absenceRate >= warningPercent && absenceRate < deprivationPercent;
        final isDeprivation = absenceRate >= deprivationPercent;

        courses.add(CourseAttendanceSummary(
          courseName: courseName,
          courseNameAr: courseNameAr,
          sectionId: sectionId,
          totalLectures: totalLectures,
          presentCount: presentCount,
          absentCount: absentCount,
          excusedCount: excusedCount,
          absenceRate: absenceRate,
          remainingBeforeDeprivation: remainingBeforeDeprivation,
          isWarning: isWarning,
          isDeprivation: isDeprivation,
        ));

        contextLines.add(
          'Course: $displayCourseName | totalLectures: $totalLectures | '
          'present: $presentCount | unexcused absent: $absentCount | '
          'excused: $excusedCount | absenceRate: ${absenceRate.toStringAsFixed(1)}% | '
          'remainingBeforeDeprivation: $remainingBeforeDeprivation',
        );
      }

      final rawContextString = contextLines.isEmpty
          ? 'No enrollments or attendance data.'
          : contextLines.join('\n');

      return AttendanceContext(
        studentId: studentIdStr,
        studentName: studentName,
        courses: courses,
        warningPercent: warningPercent,
        deprivationPercent: deprivationPercent,
        rawContextString: rawContextString,
      );
    } catch (e) {
      rethrow;
    }
  }
}
