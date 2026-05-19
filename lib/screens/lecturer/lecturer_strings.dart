import 'lecturer_language.dart';

/// Centralized static UI strings for the lecturer role.
///
/// Keys follow `lecturer.<feature>.<label>` naming for documentation.
/// Runtime selection uses [LecturerLanguageController.tr].
class LecturerStrings {
  LecturerStrings._();

  static String tr(String ar, String en, {LecturerLanguage? language}) =>
      LecturerLanguageController.tr(ar, en, language: language);

  // lecturer.notifications.*
  static String notificationsQuickOverview({LecturerLanguage? language}) =>
      tr('نظرة سريعة', 'Quick Overview', language: language);

  static String notificationsUnread({LecturerLanguage? language}) =>
      tr('غير مقروءة', 'Unread', language: language);

  static String notificationsExcuses({LecturerLanguage? language}) =>
      tr('طلبات الأعذار', 'Excuses', language: language);

  static String notificationsToday({LecturerLanguage? language}) =>
      tr('تنبيهات اليوم', 'Today', language: language);

  static String notificationsDeleteAll({LecturerLanguage? language}) =>
      tr('حذف كل الإشعارات', 'Delete all notifications', language: language);

  static String notificationsStudentSent({LecturerLanguage? language}) =>
      tr('تأكيد إرسال إشعارات الطلاب', 'Student notifications sent', language: language);

  static String notificationsPersonal({LecturerLanguage? language}) =>
      tr('شخصي', 'Personal', language: language);

  static String notificationsAlert({LecturerLanguage? language}) =>
      tr('تنبيه', 'Alert', language: language);

  static String notificationsOlder({LecturerLanguage? language}) =>
      tr('أقدم', 'Older', language: language);

  static String notificationsTitle({LecturerLanguage? language}) =>
      tr('التنبيهات', 'Notifications', language: language);

  static String notificationsThisWeek({LecturerLanguage? language}) =>
      tr('هذا الأسبوع', 'This Week', language: language);

  static String notificationsNew({LecturerLanguage? language}) =>
      tr('جديد', 'New', language: language);

  static String notificationsLoading({LecturerLanguage? language}) =>
      tr('جاري تحميل الإشعارات...', 'Loading notifications...', language: language);

  static String notificationsExcuseRequest({LecturerLanguage? language}) =>
      tr('طلب عذر', 'Excuse request', language: language);

  static String notificationsAcademic({LecturerLanguage? language}) =>
      tr('أكاديمي', 'Academic', language: language);

  static String notificationsStudents({LecturerLanguage? language}) =>
      tr('الطلاب', 'Students', language: language);

  static String notificationsSuccess({LecturerLanguage? language}) =>
      tr('نجاح', 'Success', language: language);

  static String notificationsWarning({LecturerLanguage? language}) =>
      tr('تحذير', 'Warning', language: language);

  static String notificationsInfo({LecturerLanguage? language}) =>
      tr('معلومة', 'Info', language: language);

  // lecturer.attendance_report.*
  static String reportTitle({LecturerLanguage? language}) =>
      tr('تقرير الحضور', 'Attendance Report', language: language);

  static String reportFilterSubtitle({LecturerLanguage? language}) =>
      tr(
        'فلترة التقرير واختيار المحاضرة',
        'Filter the report and choose lecture',
        language: language,
      );

  static String reportFilters({LecturerLanguage? language}) =>
      tr('فلترة التقرير', 'Report Filters', language: language);

  static String reportCourse({LecturerLanguage? language}) =>
      tr('المقرر', 'Course', language: language);

  static String reportChooseCourseFirst({LecturerLanguage? language}) =>
      tr(
        'يرجى اختيار المقرر لعرض الأسابيع',
        'Please select a course to view weeks',
        language: language,
      );

  static String reportWeek({LecturerLanguage? language}) =>
      tr('الأسبوع', 'Week', language: language);

  static String reportResetFilters({LecturerLanguage? language}) =>
      tr('إعادة ضبط الفلتر', 'Reset filters', language: language);

  static String reportWeekLectures({LecturerLanguage? language}) =>
      tr('محاضرات الأسبوع', 'Week Lectures', language: language);

  static String sectionLabel(String section, {LecturerLanguage? language}) =>
      LecturerLanguageController.localizedSectionLabel(section, language: language);

  static String profileDepartmentLabel({LecturerLanguage? language}) =>
      tr('القسم', 'Department', language: language);

  static String profileNotSpecified({LecturerLanguage? language}) =>
      tr('غير محدد', 'Not specified', language: language);
}
