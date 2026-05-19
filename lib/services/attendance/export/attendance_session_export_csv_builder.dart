import 'attendance_session_export_model.dart';

class AttendanceSessionExportCsvBuilder {
  AttendanceSessionExportCsvBuilder._();

  static String build(AttendanceSessionExportModel model) {
    final buf = StringBuffer();
    final loc = model.locale;
    final session = model.session;

    void meta(String label, String value) {
      buf.writeln('${_escapeCsv(label)},${_escapeCsv(value)}');
    }

    buf.writeln(
      '${_escapeCsv(loc.colField)},${_escapeCsv(loc.colValue)}',
    );
    meta(loc.sectionExportInfo, '');
    meta(loc.labelGeneratedAt, model.generatedAtDisplay);
    if (model.lecturerName.isNotEmpty) {
      meta(loc.labelExportedBy, model.lecturerName);
    }
    meta(loc.labelReportLanguage, loc.reportLanguageValue);

    meta(loc.sectionMetadata, '');
    meta(loc.labelCourseName, model.localizedCourseName);
    if (session.courseCode != null && session.courseCode!.isNotEmpty) {
      meta(loc.labelCourseCode, session.courseCode!);
    }
    meta(loc.labelSection, model.sectionDisplay);
    meta(loc.labelLectureDate, model.lectureDateIso);
    meta(loc.labelLectureTime, model.lectureTimeRange);
    meta(loc.labelDayOfWeek, model.dayOfWeekLabel);
    meta(loc.labelAttendanceMethod, model.attendanceMethodLabel);
    meta(loc.labelSessionId, session.sessionId);
    if (session.termId != null && session.termId!.isNotEmpty) {
      meta(loc.labelTermId, session.termId!);
    }
    if (model.isDefaultPresent) {
      meta(loc.sectionNote, loc.defaultPresentNote);
    }

    final s = model.summary;
    buf.writeln();
    meta(loc.sectionSummary, '');
    meta(loc.labelTotalStudents, '${s.totalStudents}');
    meta(loc.labelPresentCount, '${s.presentCount}');
    meta(loc.labelAbsentCount, '${s.absentCount}');
    meta(loc.labelExcusedCount, '${s.excusedCount}');
    meta(loc.labelLateCount, '${s.lateCount}');
    if (s.pendingCount > 0) {
      meta(loc.labelPendingCount, '${s.pendingCount}');
    }
    meta(loc.labelSessionAttendancePct, '${s.sessionAttendancePct}%');
    meta(loc.labelSessionAbsencePct, '${s.sessionAbsencePct}%');
    meta(loc.labelDeprivedStudentsCount, '${s.deprivedStudentsCount}');

    buf.writeln();
    meta(loc.sectionStudents, '');
    buf.writeln(
      [
        loc.colStudentId,
        loc.colStudentName,
        loc.colStatus,
        loc.colStatusCode,
        loc.colAttendanceTime,
        loc.colTotalAbsencePct,
        loc.colUnexcusedAbsencePct,
        loc.colExcusedAbsencePct,
        loc.colAcademicDeprivation,
      ].map(_escapeCsv).join(','),
    );

    for (final row in model.students) {
      buf.writeln(
        [
          _escapeCsv('${row.studentId}'),
          _escapeCsv(row.studentName),
          _escapeCsv(row.statusLabel),
          _escapeCsv(row.statusCode),
          _escapeCsv(row.attendanceTime),
          _escapeCsv(row.totalAbsencePctDisplay),
          _escapeCsv(row.unexcusedAbsencePctDisplay),
          _escapeCsv(row.excusedAbsencePctDisplay),
          _escapeCsv(row.deprivationLabel),
        ].join(','),
      );
    }

    return buf.toString();
  }

  static String _escapeCsv(String value) {
    final s = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
