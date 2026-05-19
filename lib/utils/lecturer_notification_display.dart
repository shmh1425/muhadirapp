import '../models/notifications/lecturer_notification.dart';
import '../services/lecturer/lecturer_course_name_index.dart';
import 'localized_firestore_fields.dart';

/// Resolves lecturer notification titles/messages for the active UI language.
class LecturerNotificationDisplay {
  LecturerNotificationDisplay._();

  static const Map<String, String> _knownTitleArByEn = {
    'student notifications sent': 'تأكيد إرسال إشعارات الطلاب',
    'student excuse request': 'طلب عذر من طالب',
  };

  static Map<String, dynamic> _map(LecturerNotification n) => {
        'titleAr': n.titleAr,
        'titleEn': n.titleEn,
        'messageAr': n.messageAr,
        'messageEn': n.messageEn,
        'courseNameAr': n.courseNameAr,
        'courseNameEn': n.courseNameEn,
        'courseName': n.courseName,
      };

  static String title(LecturerNotification n, {required bool isArabic}) {
    final ar = n.titleAr.trim();
    final en = n.titleEn.trim();

    if (isArabic && ar.isNotEmpty) return ar;
    if (!isArabic && en.isNotEmpty) return en;

    final knownAr = _knownTitleArByEn[en.toLowerCase()];
    if (isArabic && knownAr != null && knownAr.isNotEmpty) return knownAr;

    return LocalizedFirestoreFields.localizedNotificationTitle(
      _map(n),
      isArabic: isArabic,
      fallback: resolveCourseName(n, isArabic: isArabic),
    );
  }

  static String message(LecturerNotification n, {required bool isArabic}) {
    final rebuiltAction = _rebuildLectureActionMessage(n, isArabic: isArabic);
    if (rebuiltAction != null) {
      return rebuiltAction;
    }

    final ar = n.messageAr.trim();
    final en = n.messageEn.trim();
    String picked;
    if (isArabic) {
      picked = ar.isNotEmpty ? ar : en;
    } else {
      picked = en.isNotEmpty ? en : ar;
    }

    if (picked.isEmpty && n.isExcuseRequest) {
      picked = _rebuildExcuseMessage(n, isArabic: isArabic);
    }

    return _normalizeCourseNamesInMessage(n, picked, isArabic: isArabic);
  }

  /// Bilingual course title for notifications (Firestore + catalog fallback).
  static String resolveCourseName(
    LecturerNotification n, {
    required bool isArabic,
  }) {
    var fromFields = n.localizedCourseName(isArabic: isArabic);
    if (_isAcceptableCourseName(fromFields, isArabic: isArabic)) {
      return fromFields;
    }

    final fromCatalog = LecturerCourseNameIndex.instance.lookup(
      courseCode: n.courseCode,
      sectionId: n.sectionId,
    );
    if (fromCatalog != null) {
      final picked = fromCatalog.pick(isArabic: isArabic);
      if (picked.trim().isNotEmpty) return picked.trim();
    }

    return fromFields.trim().isNotEmpty
        ? fromFields.trim()
        : n.courseCode.trim();
  }

  static bool _isAcceptableCourseName(String name, {required bool isArabic}) {
    final value = name.trim();
    if (value.isEmpty) return false;
    final hasArabic = LocalizedFirestoreFields.containsArabicScript(value);
    if (isArabic) return hasArabic || !value.contains(' ');
    return !hasArabic;
  }

  static String? _rebuildLectureActionMessage(
    LecturerNotification n, {
    required bool isArabic,
  }) {
    final action = n.actionType.trim().toLowerCase();
    if (action != 'delay' && action != 'cancel') return null;

    final count = n.recipientsCount ?? 0;
    final course = resolveCourseName(n, isArabic: isArabic);
    final section = n.section.trim().isNotEmpty
        ? n.section.trim()
        : n.sectionId.trim();
    final delay = n.delayMinutes ?? 0;

    if (isArabic) {
      if (count <= 0) {
        return 'لم يتم العثور على طلاب مسجلين للشعبة $section في "$course" لإرسال الإشعار.';
      }
      switch (action) {
        case 'delay':
          return 'تم إشعار $count طالب/ـة بتأخير محاضرة "$course" للشعبة $section لمدة $delay دقيقة.';
        case 'cancel':
          return 'تم إشعار $count طالب/ـة بإلغاء محاضرة "$course" للشعبة $section.';
      }
    } else {
      if (count <= 0) {
        return 'No enrolled students were found for section $section in "$course".';
      }
      switch (action) {
        case 'delay':
          return '$count students were notified about delaying "$course" (section $section) by $delay minutes.';
        case 'cancel':
          return '$count students were notified about cancelling "$course" (section $section).';
      }
    }
    return null;
  }

  static String _rebuildExcuseMessage(
    LecturerNotification n, {
    required bool isArabic,
  }) {
    final course = resolveCourseName(n, isArabic: isArabic);
    if (isArabic) {
      return 'تم رفع عذر لمادة "$course". يمكنك مراجعة الطلب واتخاذ إجراء.';
    }
    return 'A new excuse was submitted for "$course". You can review and take action.';
  }

  static String _normalizeCourseNamesInMessage(
    LecturerNotification n,
    String message, {
    required bool isArabic,
  }) {
    if (message.trim().isEmpty) return message;

    final target = resolveCourseName(n, isArabic: isArabic);
    if (target.isEmpty) return message;

    final variants = <String>{
      n.courseName.trim(),
      n.courseNameAr.trim(),
      n.courseNameEn.trim(),
    };

    final fromCatalog = LecturerCourseNameIndex.instance.lookup(
      courseCode: n.courseCode,
      sectionId: n.sectionId,
    );
    if (fromCatalog != null) {
      variants.add(fromCatalog.ar);
      variants.add(fromCatalog.en);
    }

    var result = message;
    for (final snapshot in variants) {
      if (snapshot.isEmpty || snapshot == target) continue;
      result = result.replaceAll(snapshot, target);
    }
    return result;
  }
}
