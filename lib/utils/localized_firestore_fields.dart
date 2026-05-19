/// Language-aware pickers for bilingual Firestore document fields.
///
/// Static UI labels belong in [LecturerLanguageController.tr] / translation files.
/// Dynamic names (courses, people, departments) should use these helpers.
class LocalizedFirestoreFields {
  LocalizedFirestoreFields._();

  static String _trim(dynamic v) => (v ?? '').toString().trim();

  static bool containsArabicScript(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  static String localizedCourseName(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const [
      'courseNameAr',
      'courseName_Ar',
      'course_name_ar',
    ]);
    final enExplicit = _firstNonEmpty(data, const [
      'courseNameEn',
      'courseName_En',
      'course_name_en',
    ]);
    final courseNameGeneric = _trim(data['courseName']);

    if (isArabic) {
      if (ar.isNotEmpty) return ar;
      if (enExplicit.isNotEmpty) return enExplicit;
      if (courseNameGeneric.isNotEmpty &&
          containsArabicScript(courseNameGeneric)) {
        return courseNameGeneric;
      }
      if (courseNameGeneric.isNotEmpty) return courseNameGeneric;
      return fallback;
    }

    if (enExplicit.isNotEmpty && !containsArabicScript(enExplicit)) {
      return enExplicit;
    }
    if (courseNameGeneric.isNotEmpty &&
        !containsArabicScript(courseNameGeneric) &&
        courseNameGeneric != ar) {
      return courseNameGeneric;
    }
    if (ar.isNotEmpty) return ar;
    return fallback;
  }

  /// Known English → Arabic labels when Firestore has no `collegeAr` field.
  static const Map<String, String> _collegeEnToAr = {
    'computing': 'الحاسبات',
    'business and economics': 'إدارة الأعمال والاقتصاد',
  };

  /// Known English → Arabic labels when Firestore has no `departmentAr` field.
  static const Map<String, String> _departmentEnToAr = {
    'software engineering': 'هندسة البرمجيات',
    'economics': 'الاقتصاد',
    'business administration': 'إدارة الأعمال',
  };

  static String localizedCollege(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const [
      'collegeAr',
      'college_ar',
    ]);
    final en = _firstNonEmpty(data, const [
      'collegeEn',
      'college_en',
      'college',
    ]);
    return _pickAcademicUnit(
      ar: ar,
      en: en,
      isArabic: isArabic,
      fallback: fallback,
      knownArByEn: _collegeEnToAr,
    );
  }

  static String localizedDepartment(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const [
      'departmentAr',
      'department_ar',
    ]);
    final en = _firstNonEmpty(data, const [
      'departmentEn',
      'department_en',
      'department',
    ]);
    return _pickAcademicUnit(
      ar: ar,
      en: en,
      isArabic: isArabic,
      fallback: fallback,
      knownArByEn: _departmentEnToAr,
    );
  }

  static String _pickAcademicUnit({
    required String ar,
    required String en,
    required bool isArabic,
    required String fallback,
    required Map<String, String> knownArByEn,
  }) {
    if (isArabic) {
      if (ar.isNotEmpty) return ar;
      final mapped = knownArByEn[en.trim().toLowerCase()];
      if (mapped != null && mapped.isNotEmpty) return mapped;
      if (en.isNotEmpty) return en;
    } else {
      if (en.isNotEmpty) return en;
      if (ar.isNotEmpty) return ar;
    }
    return fallback;
  }

  static String localizedPersonName(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const [
      'nameAr',
      'name_ar',
      'studentNameAr',
      'student_name_ar',
      'lecturerNameAr',
      'lecturer_name_ar',
    ]);
    final enExplicit = _firstNonEmpty(data, const [
      'nameEn',
      'name_en',
      'studentNameEn',
      'student_name_en',
      'lecturerNameEn',
      'lecturer_name_en',
    ]);
    final generic = _firstNonEmpty(data, const [
      'name',
      'studentName',
      'student_name',
      'lecturerName',
      'lecturer_name',
    ]);

    if (isArabic) {
      if (ar.isNotEmpty) return ar;
      if (generic.isNotEmpty && containsArabicScript(generic)) return generic;
      if (enExplicit.isNotEmpty) return enExplicit;
      if (generic.isNotEmpty) return generic;
    } else {
      if (enExplicit.isNotEmpty) return enExplicit;
      if (generic.isNotEmpty && !containsArabicScript(generic)) return generic;
      if (ar.isNotEmpty) return ar;
      if (generic.isNotEmpty) return generic;
    }
    return fallback;
  }

  static String localizedNotificationTitle(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const ['titleAr', 'title_ar']);
    final en = _firstNonEmpty(data, const ['titleEn', 'title_en', 'title']);
    return _pickBilingual(ar: ar, en: en, isArabic: isArabic, fallback: fallback);
  }

  static String localizedNotificationMessage(
    Map<String, dynamic> data, {
    required bool isArabic,
    String fallback = '',
  }) {
    final ar = _firstNonEmpty(data, const ['messageAr', 'message_ar']);
    final en = _firstNonEmpty(data, const [
      'messageEn',
      'message_en',
      'message',
    ]);
    return _pickBilingual(ar: ar, en: en, isArabic: isArabic, fallback: fallback);
  }

  static String localizedSectionLabel(
    String section, {
    required bool isArabic,
    required String Function(String ar, String en) tr,
  }) {
    final value = section.trim();
    if (value.isEmpty) return '';
    return '${tr('الشعبة', 'Section')} $value';
  }

  /// Replaces a snapshot course name embedded in a notification body.
  static String replaceEmbeddedCourseName({
    required String message,
    required String snapshotCourseName,
    required String localizedCourseName,
  }) {
    final snapshot = snapshotCourseName.trim();
    final localized = localizedCourseName.trim();
    if (message.trim().isEmpty ||
        snapshot.isEmpty ||
        localized.isEmpty ||
        snapshot == localized) {
      return message;
    }
    return message.replaceAll(snapshot, localized);
  }

  static String localizedActivity(
    String raw, {
    required bool isArabic,
    required String Function(String ar, String en) tr,
  }) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'lab':
      case 'عملي':
        return tr('عملي', 'Lab');
      case 'theory':
      case 'نظري':
        return tr('نظري', 'Theory');
      default:
        if (raw.trim().isEmpty) return tr('نظري', 'Theory');
        return raw.trim();
    }
  }

  static String _firstNonEmpty(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = _trim(data[key]);
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static String _pickBilingual({
    required String ar,
    required String en,
    required bool isArabic,
    required String fallback,
  }) {
    if (isArabic) {
      if (ar.isNotEmpty) return ar;
      if (en.isNotEmpty) return en;
    } else {
      if (en.isNotEmpty) return en;
      if (ar.isNotEmpty) return ar;
    }
    return fallback;
  }
}
