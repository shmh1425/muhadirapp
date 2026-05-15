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
  static String get acceptedBannerStatus => tr('مقبول', 'Accepted');
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

  static String get priorRejectionAlertTitle =>
      tr('تنبيه: رفض سابق', 'Alert: prior rejection');
  static String get priorRejectionAlertLead => tr(
    'تم رفض الطالبة مسبقاً اليوم عند هذه البوابة للسبب التالي:',
    'This student was already rejected at this gate today for the following reason:',
  );
  static String get priorRejectionAlertFooter => tr(
    'اضغطي «تأكيد ودخول» للمتابعة إلى نافذة التحقق، أو «إلغاء» للعودة.',
    'Tap “Confirm entry” to open the verification screen, or “Cancel” to go back.',
  );
  static String get priorRejectionAlertContinue =>
      tr('تأكيد ودخول', 'Confirm entry');
  static String get priorRejectionAlertCancel => tr('إلغاء', 'Cancel');

  static String get nfcGateVerificationTitle =>
      tr('التحقق عبر NFC أو QR', 'NFC or QR gate verification');
  static String get gateCardVerificationTitle =>
      tr('التحقق من البطاقة', 'Card verification');
  static String get cardDataSectionTitle =>
      tr('بيانات البطاقة', 'Card details');
  static String get confirmEntry => tr('تأكيد الدخول', 'Confirm entry');
  static String get rejectEntry => tr('رفض الدخول', 'Reject entry');
  static String get nfcGateVerificationSubtitle => tr(
    'امسحي بطاقة الطالبة (NFC) أو رمز QR المعروض على بطاقتها في التطبيق.',
    'Scan the student card (NFC) or the QR code shown on her card in the app.',
  );
  static String get nfcStartScan => tr('بدء قراءة البطاقة', 'Start card scan');
  static String get nfcScanningHint => tr(
    'قرّبي البطاقة أو الجهاز من أعلى الهاتف…',
    'Hold the card or phone near the top of this device…',
  );
  static String get nfcNotAvailableWeb => tr(
    'NFC غير مدعوم على المتصفح. استخدمي التطبيق على iOS/Android في جهاز حقيقي.',
    'NFC is not supported in the browser. Use the iOS/Android app on a real device.',
  );
  static String get nfcNotAvailableDevice =>
      tr('NFC غير متاح على هذا الجهاز', 'NFC is not available on this device');
  static String get nfcReadFailed =>
      tr('تعذرت قراءة البطاقة', 'Could not read the card');
  static String get nfcUnknownStudent => tr(
    'لم يُعثر على طالبة مطابقة لهذا المعرّف',
    'No student matched this identifier',
  );
  static String get nfcUidLabel => tr('معرّف القراءة', 'Read identifier');
  static String get nfcContinueHumanVerification =>
      tr('متابعة التحقق البصري', 'Continue to visual verification');
  static String get nfcScanAgain => tr('مسح جديد', 'Scan again');
  static String get nfcHintFirestoreField => tr(
    'يتم البحث في الحقل securityGateNfcUid أو الرقم الجامعي أو رقم البطاقة من QR/NFC',
    'Lookup uses securityGateNfcUid, university ID, or card number from QR/NFC',
  );

  static String get gateReaderModeNfc => tr('NFC', 'NFC');
  static String get gateReaderModeQr => tr('QR', 'QR');
  static String get gateDualModeSecurityHint => tr(
    'QR يعمل مع iPhone وأندرويد. NFC لبطاقة فعلية أو جوال أندرويد عند القارئ.',
    'QR works on iPhone and Android. NFC is for physical cards or Android phones at the reader.',
  );
  static String get gateQrModeHint => tr(
    'لو كانت بطاقة الطالبة على iPhone فاختاري QR وامسحي الرمز من شاشة البطاقة.',
    'If the student card is on iPhone, use QR mode and scan the code from the card screen.',
  );
  static String get gateNfcModeHint => tr(
    'NFC هنا مخصص لبطاقات NFC أو Android HCE. بطاقات iPhone تُقرأ عبر QR.',
    'NFC mode reads physical NFC tags or Android HCE. iPhone cards are verified via QR.',
  );
  static String get qrScanHint => tr(
    'وجّهي الكاميرا نحو رمز QR على البطاقة.',
    'Point the camera at the QR on the card.',
  );
  static String get qrInvalidGatePayload => tr(
    'رمز QR غير صالح لهذه البوابة',
    'This QR code is not valid for this gate',
  );
  static String get qrCameraPermissionDenied => tr(
    'لم يتم السماح باستخدام الكاميرا. فعّلي صلاحية الكاميرا لمسح رمز QR.',
    'Camera permission is not granted. Enable camera access to scan the QR code.',
  );
  static String get qrNotOnWeb => tr(
    'مسح QR غير متاح في المتصفح. استخدمي تطبيق الأمن على الهاتف.',
    'QR scanning is not available in the browser. Use the security app on a phone.',
  );
  static String get qrProcessing => tr('جاري التحقق…', 'Verifying…');
  static String get qrResumeScanning => tr('متابعة المسح', 'Continue scanning');
  static String get gateCardRevStale => tr(
    'رمز البطاقة لم يعد صالحاً (مثلاً بعد انسحاب أو تحديث وضع الطالبة). يُرجى فتح بطاقة الطالبة من جديد لتحديث الرمز.',
    'This gate card code is no longer valid (e.g. after withdrawal or status update). Ask the student to open the card screen to refresh the code.',
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
