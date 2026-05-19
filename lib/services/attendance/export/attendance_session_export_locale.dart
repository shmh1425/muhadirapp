import '../../../models/attendance/manual_attendance_record.dart';
import '../../../screens/lecturer/lecturer_language.dart';

/// Localized labels for attendance session export (CSV + PDF).
class AttendanceSessionExportLocale {
  AttendanceSessionExportLocale._({required this.isArabic});

  factory AttendanceSessionExportLocale.fromLanguage({
    bool? isArabic,
  }) {
    final arabic = isArabic ?? LecturerLanguageController.isArabic;
    return AttendanceSessionExportLocale._(isArabic: arabic);
  }

  final bool isArabic;

  String _t(String ar, String en) =>
      isArabic ? ar : en;

  String get reportTitle => _t('تقرير حضور المحاضرة', 'Lecture Attendance Report');

  String get sectionExportInfo => _t('معلومات التصدير', 'Export Information');
  String get sectionMetadata => _t('بيانات المحاضرة', 'Session Information');
  String get colField => _t('الحقل', 'Field');
  String get colValue => _t('القيمة', 'Value');
  String get sectionSummary => _t('الملخص', 'Summary');
  String get sectionStudents => _t('الطلاب', 'Students');
  String get sectionNote => _t('ملاحظة', 'Note');

  String get labelGeneratedAt => _t('تاريخ ووقت التصدير', 'Export date and time');
  String get labelExportedBy => _t('صدر بواسطة', 'Exported by');
  String get labelReportLanguage => _t('لغة التقرير', 'Report language');
  String get reportLanguageValue =>
      isArabic ? _t('العربية', 'Arabic') : _t('الإنجليزية', 'English');
  String get labelAttendanceMethod => _t('طريقة التحضير', 'Attendance method');
  String get attendanceMethodDefaultPresent => _t(
        'حضور افتراضي',
        'Default present',
      );
  String get attendanceMethodManual => _t('تحضير يدوي', 'Manual');
  String get attendanceMethodQr => _t('تحضير QR', 'QR');
  String get attendanceMethodNfc => _t('تحضير NFC', 'NFC');
  String get attendanceMethodBluetooth => _t('تحضير بلوتوث', 'Bluetooth');
  String get labelSessionId => _t('معرف الجلسة', 'Session ID');
  String get labelSectionId => _t('معرف الشعبة', 'Section ID');
  String get labelCourseName => _t('اسم المقرر', 'Course name');
  String get labelCourseCode => _t('رمز المقرر', 'Course code');
  String get labelSection => _t('الشعبة', 'Section');
  String get labelLectureDate => _t('تاريخ المحاضرة', 'Lecture date');
  String get labelLectureTime => _t('وقت المحاضرة', 'Lecture time');
  String get labelDayOfWeek => _t('يوم الأسبوع', 'Day of week');
  String get labelTermId => _t('معرف الفصل', 'Term ID');
  String get labelOfficialWeek => _t('الأسبوع الرسمي', 'Official week');
  String get labelEffectiveWeek => _t('الأسبوع الفعلي', 'Effective week');
  String get labelLecturer => _t('المحاضر', 'Lecturer');
  String get labelDefaultPresentPolicy => _t(
        'سياسة الحضور الافتراضي',
        'Default attendance policy',
      );

  String get defaultPresentNote => _t(
        'لم يتم فتح جلسة حضور لهذه المحاضرة، وتم احتساب الطلاب حضورًا افتراضيًا حسب سياسة النظام.',
        'No attendance session was opened for this lecture; students were counted as present by default according to system policy.',
      );

  String get labelTotalStudents => _t('إجمالي الطلاب', 'Total students');
  String get labelPendingCount => _t('بانتظار التحضير', 'Pending attendance');
  String get labelPresentCount => _t('حاضر', 'Present');
  String get labelAbsentCount => _t('غائب', 'Absent');
  String get labelExcusedCount => _t('غياب بعذر', 'Excused');
  String get labelLateCount => _t('متأخر', 'Late');
  String get labelPresentPct => _t('نسبة الحضور %', 'Present %');
  String get labelAbsentPct => _t('نسبة الغياب %', 'Absent %');
  String get labelExcusedPct => _t('نسبة الغياب بعذر %', 'Excused %');
  String get labelLatePct => _t('نسبة التأخر %', 'Late %');
  String get labelSessionAttendancePct =>
      _t('نسبة حضور الجلسة', 'Session attendance %');
  String get labelSessionAbsencePct =>
      _t('نسبة غياب الجلسة', 'Session absence %');
  String get labelDeprivedStudentsCount => _t(
        'عدد الطلاب المحرومين أكاديميًا',
        'Academically deprived students',
      );

  String get colTotalAbsencePct =>
      _t('نسبة الغياب الإجمالية', 'Total Absence %');
  String get colUnexcusedAbsencePct =>
      _t('نسبة الغياب بدون عذر', 'Unexcused Absence %');
  String get colExcusedAbsencePct =>
      _t('نسبة الغياب بعذر', 'Excused Absence %');
  String get colAcademicDeprivation =>
      _t('حالة الحرمان', 'Academic Deprivation');
  String get deprivedYes => _t('محروم أكاديميًا', 'Academically Deprived');
  String get deprivedNo => _t('غير محروم', 'Not Deprived');

  String get colRecordId => _t('معرف السجل', 'Record ID');
  String get colStudentId => _t('رقم الطالب', 'Student ID');
  String get colStudentName => _t('اسم الطالب', 'Student name');
  String get colStatus => _t('الحالة', 'Status');
  String get colStatusCode => _t('رمز الحالة', 'Status code');
  String get colAttendanceTime => _t('وقت التحضير', 'Attendance time');
  String get colCourseCode => _t('رمز المقرر', 'Course code');
  String get colLectureStart => _t('بداية المحاضرة', 'Lecture start');
  String get colLectureEnd => _t('نهاية المحاضرة', 'Lecture end');

  String get valueYes => _t('نعم', 'Yes');
  String get valueNo => _t('لا', 'No');

  String statusLabel(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.present:
        return labelPresentCount;
      case ManualAttendanceStatus.absent:
        return labelAbsentCount;
      case ManualAttendanceStatus.excused:
        return labelExcusedCount;
      case ManualAttendanceStatus.late:
        return labelLateCount;
      case ManualAttendanceStatus.pending:
        return labelPendingCount;
    }
  }

  String dayNameFromWeekday(int weekday) =>
      LecturerLanguageController.dayNameFromWeekday(
        weekday,
        language: isArabic
            ? LecturerLanguage.arabic
            : LecturerLanguage.english,
      );

  String sectionDisplayLabel(String sectionNumber) {
    final value = sectionNumber.trim();
    if (value.isEmpty) return '';
    return '${_t('الشعبة', 'Section')} $value';
  }

  String attendanceMethodLabel(String rawMethod, {required bool isDefaultPresent}) {
    if (isDefaultPresent) return attendanceMethodDefaultPresent;
    switch (rawMethod.trim().toLowerCase()) {
      case 'manual':
        return attendanceMethodManual;
      case 'qr':
        return attendanceMethodQr;
      case 'nfc':
        return attendanceMethodNfc;
      case 'bluetooth':
        return attendanceMethodBluetooth;
      case 'default_present':
        return attendanceMethodDefaultPresent;
      default:
        final m = rawMethod.trim();
        return m.isEmpty ? _t('غير محدد', 'Not specified') : m;
    }
  }
}
