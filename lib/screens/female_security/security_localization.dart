import 'package:flutter/widgets.dart';

import '../../features/translation/translation_controller.dart';

class SecurityLocalization {
  SecurityLocalization._();

  static TranslationController get controller => TranslationController.instance;

  static bool get isEnglish => controller.translateToEnglish;
  static bool get isArabic => !isEnglish;
  static TextDirection get direction => controller.textDirection;

  static String tr(String ar, String en) => isEnglish ? en : ar;

  static String get acceptedStudents => tr('المقبولين', 'Accepted Students');
  static String get rejectedStudents => tr('المرفوضين', 'Rejected Students');
  static String get acceptedStatus => tr('تم الدخول', 'Accepted');
  static String get rejectedStatus => tr('مرفوض', 'Rejected');
  static String get location => tr('الموقع', 'Location');
  static String get gate => tr('بوابة رقم', 'Gate');
  static String get date => tr('التاريخ', 'Date');
  static String get searchHint =>
      tr('بحث بالإسم أو الرقم الجامعي', 'Search by name or university ID');
  static String get studentName => tr('اسم الطالب/ة', 'Student Name');
  static String get studentNameFemale => tr('اسم الطالبة', 'Student Name');
  static String get universityId => tr('الرقم الجامعي', 'University ID');
  static String get scanTime => tr('الوقت', 'Scan Time');
  static String get previewCard => tr('معاينة البطاقة', 'View Card');
  static String get preview => tr('معاينة', 'View');
  static String get reason => tr('السبب', 'Reason');
  static String get rejectionReason => tr('سبب الرفض', 'Rejection Reason');
  static String get rejectionReasonWhenNeeded =>
      tr('سبب الرفض عند الحاجة', 'Rejection reason if needed');
  static String get noReasonRecorded =>
      tr('لا يوجد سبب مسجل', 'No reason recorded');
  static String get noAcceptedStudents =>
      tr('لا توجد سجلات مقبولة لهذا اليوم والبوابة', 'No accepted students');
  static String get noRejectedStudents =>
      tr('لا توجد سجلات مرفوضة لهذا اليوم والبوابة', 'No rejected students');
  static String get acceptedLoadError => tr(
    'تعذر تحميل سجلات المقبولين من student_gate_scans',
    'Could not load accepted student records',
  );
  static String get rejectedLoadError => tr(
    'تعذر تحميل سجلات المرفوضين من student_gate_scans',
    'Could not load rejected student records',
  );
  static String get settings => tr('الإعدادات', 'Settings');
  static String get language => tr('اللغة', 'Language');
  static String get arabic => tr('العربية', 'Arabic');
  static String get english => tr('الإنجليزية', 'English');
  static String get notifications => tr('الإشعارات', 'Notifications');
  static String get rateExperience => tr('قيم تجربتك', 'Rate your experience');
  static String get generalSettings =>
      tr('الإعدادات العامة', 'General Settings');
  static String get automaticUpdates =>
      tr('التحديثات التلقائية', 'Automatic Updates');
  static String get darkMode => tr('الوضع الليلي', 'Dark Mode');
  static String get automatic => tr('تلقائي', 'Automatic');
  static String get enabled => tr('مفعل', 'Enabled');
  static String get disabled => tr('مغلق', 'Disabled');
  static String gateLabel(int gateNumber) =>
      tr('البوابة: $gateNumber', 'Gate: $gateNumber');
  static String campusName(String campusName) {
    final normalized = campusName.trim();
    if (!isEnglish) return normalized;
    if (normalized == 'الزاهر') return 'Al-Zaher';
    return normalized;
  }

  static String gateOptionLabel({
    required int gateNumber,
    required String campusName,
  }) {
    final displayCampus = SecurityLocalization.campusName(campusName);
    return isEnglish
        ? '$displayCampus - $gateNumber'
        : '$displayCampus - $gateNumber';
  }

  static String get logout => tr('تسجيل الخروج', 'Logout');
  static String get confirmLogout => tr(
    'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    'Are you sure you want to log out?',
  );
  static String get cancel => tr('إلغاء', 'Cancel');
  static String get confirm => tr('تأكيد', 'Confirm');
  static String get reject => tr('رفض', 'Reject');
  static String get selectRejectionReason =>
      tr('اختاري سبب الرفض أولاً', 'Choose a rejection reason first');
  static String saveEntryError(Object error) =>
      tr('تعذر حفظ سجل الدخول: $error', 'Could not save gate entry: $error');
  static String get securityAccount => tr('حساب الأمن', 'Security Account');
  static String get photoUpdated =>
      tr('تم تحديث الصورة الشخصية بنجاح', 'Profile photo updated successfully');
  static String get photoUploadFailed => tr(
    'تعذر رفع الصورة، يرجى المحاولة مرة أخرى',
    'Could not upload photo. Please try again.',
  );
  static String get entryTime => tr('وقت الدخول', 'Entry Time');
  static String get major => tr('التخصص', 'Major');
  static String get duplicateEntryDetected =>
      tr('تم اكتشاف دخول مكرر', 'Duplicate Entry Detected');
  static String get thisStudentAlreadyAcceptedToday => tr(
    'تم قبول هذه الطالبة مسبقًا عند هذه البوابة اليوم',
    'This student has already been accepted at this gate today.',
  );

  static String dayName(DateTime date) {
    final ar = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final en = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final index = date.weekday % 7;
    return isEnglish ? en[index] : ar[index];
  }

  static String formattedDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '${dayName(date)} $d-$m-$y';
  }
}
